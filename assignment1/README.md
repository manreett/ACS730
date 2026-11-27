# ACS730 Assignment 1 — Multi-Environment Terraform Delivery & AWS Operations

**Student:** Manreet Kaur (`mkaur910`)  
**Repository:** `manreett/ACS730`  
**AWS Account:** `496177904282` (`us-east-1`)  

---

## Introduction

This report documents the design, automated delivery pipeline, secrets architecture, and operational monitoring of a reusable multi-environment web stack on AWS using Terraform (`>= 1.10.0`) and GitHub Actions. Rather than duplicating infrastructure definitions across environments, all AWS networking, security group, compute, SSM data lookup, and CloudWatch alarm resources are encapsulated inside a single parameterized child module (`assignment1/terraform/modules/web-stack/`). Three thin environment callers (`dev/`, `staging/`, and `prod/`) instantiate that module with isolated VPC CIDR blocks (`10.10.0.0/16`, `10.20.0.0/16`, and `10.30.0.0/16`) while persisting state to separate S3 object keys (`assignment1/dev/terraform.tfstate`, `assignment1/staging/terraform.tfstate`, and `assignment1/prod/terraform.tfstate`) within a single versioned state bucket (`acs730-tfstate-496177904282`) using Terraform 1.10 native S3 state locking (`use_lockfile = true`).

Delivery is governed by two path-scoped GitHub Actions workflows: `assignment1-ci.yml` enforces formatting and validation across the module and all three callers on pull requests, while `assignment1-deploy.yml` automatically applies `staging` upon merge to `main` and pauses before `prod` until a designated reviewer explicitly approves the deployment.

---

## Task 4 — Environment-Scoped Credentials & Production OIDC Trust Policy

### Credential Rotation & Environment Scoping

In the AWS Academy Learner Lab environment, IAM write operations (`iam:CreateOpenIDConnectProvider`, `iam:CreateRole`) are blocked by Service Control Policies, requiring short-lived STS session credentials (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) per lab session. To prevent pull-request workflows or unapproved branches from accessing deployment credentials, repository-level AWS secrets were deleted and credentials were scoped exclusively to the `staging` and `prod` GitHub Environments using the three-argument helper script:

    ./scripts/refresh-gha-creds.sh manreett/ACS730 staging prod

Because the `prod` GitHub Environment enforces both a required reviewer (`manreett`) and a deployment branch policy restricted strictly to `main`, GitHub Actions withholds the `prod` secrets from the runner until the branch check passes and manual approval is recorded.

### Production IAM OIDC Trust Policy (`manreett/ACS730` — `prod` Environment)

In a standard production AWS account without Learner Lab IAM restrictions, static or session-based secrets would be replaced entirely by OpenID Connect (OIDC) federation using `sts:AssumeRoleWithWebIdentity` (this policy was not deployed in the course account because AWS Academy blocks IAM identity provider and role creation). Below is the least-privilege IAM role trust policy scoped exclusively to the `prod` environment of `manreett/ACS730`:

    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Sid": "AllowGitHubActionsProdEnvironmentOIDC",
          "Effect": "Allow",
          "Principal": {
            "Federated": "arn:aws:iam::496177904282:oidc-provider/token.actions.githubusercontent.com"
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
              "token.actions.githubusercontent.com:sub": "repo:manreett/ACS730:environment:prod"
            }
          }
        }
      ]
    }

### Condition-by-Condition Security Analysis

* **`Principal.Federated` (`arn:aws:iam::496177904282:oidc-provider/token.actions.githubusercontent.com`):** Restricts trust strictly to the GitHub Actions OIDC Identity Provider registered inside AWS account `496177904282`. AWS STS validates the JSON Web Token (JWT) signature against GitHub's public JWKS keys, rejecting tokens minted by any external identity provider or rogue OIDC issuer.
* **`StringEquals` on `token.actions.githubusercontent.com:aud` (`"sts.amazonaws.com"`):** Enforces the JWT audience claim. This prevents token-replay or confused-deputy attacks where an OIDC token minted for a third-party service (such as HashiCorp Vault or an external package registry) is replayed against AWS STS to obtain temporary AWS credentials.
* **`StringEquals` on `token.actions.githubusercontent.com:sub` (`"repo:manreett/ACS730:environment:prod"`):** Binds role assumption to two simultaneous invariants in GitHub's OIDC subject claim:
  1. **Repository isolation (`repo:manreett/ACS730`):** Blocks workflows in any other GitHub repository or fork from assuming the production role.
  2. **Environment-gate binding (`:environment:prod`):** GitHub only mints an OIDC token with `:environment:prod` in the `sub` claim *after* a job explicitly declares `environment: prod` and satisfies all configured protection rules—specifically, running from the `main` branch and passing required human reviewer approval.
* **Why `repo:manreett/ACS730:environment:prod` Stops Attacks That `repo:manreett/ACS730:*` Allows:**  
  If the trust policy used `StringLike` with a repo-wide wildcard (`"repo:manreett/ACS730:*"`), **any** workflow execution anywhere in the repository—including pull requests from feature branches, `workflow_dispatch` runs on unreviewed branches, or commits pushed directly to non-`main` branches—would receive a valid OIDC token matching the wildcard. Any contributor with push access to a feature branch could modify `.github/workflows/` on their branch to call `aws-actions/configure-aws-credentials` with the production Role ARN and immediately assume full production AWS permissions, completely bypassing `main` branch protection, PR reviews, and the `prod` manual approval gate. Pinning `sub` with `StringEquals` to `repo:manreett/ACS730:environment:prod` eliminates that privilege-escalation path at the AWS IAM boundary.

---

## Task 6 — Out-of-Band SSM Parameter Store Pre-Step

Application secrets must not be hardcoded in `.tf` files or committed to Git. Before running `terraform plan` or `terraform apply` for the stack, the database password parameter was provisioned once out-of-band from the EC2 workstation using the AWS CLI:

    aws ssm put-parameter --name "/acs730/assignment1/prod/db-password" --value "S3cureAppPass2026!" --type "SecureString" --overwrite

Inside `assignment1/terraform/modules/web-stack/compute.tf`, Terraform reads this parameter exclusively via a data source (`data "aws_ssm_parameter" "db_password"`) rather than defining an `aws_ssm_parameter` resource. Creating and reading the same parameter inside one Terraform configuration creates a circular dependency during planning and forces the secret value to live inside Terraform configuration or state-creation inputs; separating out-of-band secret seeding from Terraform `data` lookups allows CI pipelines to consume existing secrets cleanly without embedding plaintext values in version control.

---

## Task 8 — CI/CD Architecture Recommendation

### Recommendation

For a small engineering team fully committed to AWS with no multi-cloud plans, **GitHub-hosted runners paired with AWS IAM OIDC federation** is the recommended CI/CD execution model, with a defined migration threshold to **self-hosted runners inside a private VPC subnet** only if the pipeline later requires direct network access to private internal endpoints.

### Evaluation Across Key Architectural Factors

1. **Where the Identity Lives:**  
   With GitHub-hosted runners and OIDC, no long-lived AWS credentials or static IAM user keys exist anywhere in GitHub or on runner disks. The identity lives in an AWS IAM role (`arn:aws:iam::496177904282:role/github-actions-prod`) whose trust policy verifies GitHub's signed OIDC JWT (`sub = repo:manreett/ACS730:environment:prod`), minting short-lived STS credentials per job. By contrast, an AWS-native pipeline (CodePipeline + CodeBuild) or a self-hosted EC2 runner relies on an attached IAM service/instance role inside AWS, which stays tightly within the AWS IAM boundary without external federation, but requires maintaining IAM trust relationships per build project and carefully restricting container/host metadata access (`IMDSv2`) so untrusted PR builds cannot inherit deployment permissions.

2. **Runner Cost and Patching Ownership:**  
   GitHub-hosted runners operate on a pure consumption model (free minutes for public repositories and per-minute billing only while jobs execute) with zero idle compute spend. GitHub owns OS image builds, kernel security patches, and pre-installed tooling updates (`terraform`, `aws-cli`, `gh`). An AWS-native CodeBuild pipeline also bills per build minute, whereas a self-hosted EC2 runner incurs continuous 24/7 hourly EC2 and EBS storage charges even when no deployments are running, and shifts ongoing OS patching, Docker/runner agent upgrades, disk cleanup, and availability monitoring onto the engineering team.

3. **Existing Team Knowledge and Workflow Proximity:**  
   The team already authors declarative YAML workflows using standard GitHub-maintained actions (`actions/checkout@v4`, `hashicorp/setup-terraform@v3`, `aws-actions/configure-aws-credentials@v4`) and GitHub Environment approval gates directly alongside pull requests and code reviews. Moving to AWS CodePipeline and CodeBuild splits pipeline visibility away from GitHub pull requests into a separate AWS Console interface and introduces CloudFormation/Terraform boilerplate for pipeline stages, artifact S3 buckets, and CodeStar connections without improving Terraform execution speed.

4. **What Breaks the Day VPC-Internal Access Is Required:**  
   GitHub-hosted runners execute on public cloud VMs outside our AWS VPCs (`10.10.0.0/16`, `10.20.0.0/16`, `10.30.0.0/16`). As long as pipelines only call public AWS control-plane APIs (`ec2`, `s3`, `ssm`, `cloudwatch`) and public HTTP endpoints, GitHub-hosted runners work seamlessly. However, the day the pipeline must run database schema migrations against a private RDS instance, execute integration tests against an internal Application Load Balancer, or query a private service without public ingress, **GitHub-hosted runners break** because they cannot route into private RFC 1918 subnets without exposing endpoints publicly or maintaining brittle bastion/VPN tunnels. At that exact inflection point, attaching CodeBuild to a private VPC subnet or deploying an ephemeral self-hosted runner inside a private VPC subnet becomes justified.

---

## Conclusion

Building a single parameterized Terraform module (`web-stack`) consumed by isolated `dev`, `staging`, and `prod` root configurations eliminated configuration drift across environments while keeping state blast radii strictly separated by S3 object key. Wiring those callers into GitHub Actions demonstrated how repository-level CI checks and environment-scoped deployment gates enforce progressive delivery: pull requests validate syntax and formatting without cloud credentials, merges to `main` promote automatically to `staging`, and `prod` remains blocked until both branch policy and human approval are satisfied.

Two operational lessons stood out during implementation. First, separating out-of-band secret creation (`aws ssm put-parameter`) from Terraform `data` source consumption keeps sensitive values out of version control while allowing automated pipelines to reference them cleanly. Second, observability resources like `aws_cloudwatch_metric_alarm` require real metric evaluation periods after creation—validating that an alarm transitions from `INSUFFICIENT_DATA` to `OK` on an active metric (`CPUUtilization`) is essential before treating monitoring as operational.