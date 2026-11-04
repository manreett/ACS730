# Lab 5: Real Terraform with LocalStack & GitHub Actions CI

## What I Built
A dual-target Terraform configuration deploying a public VPC network (VPC, public subnets mapped with `for_each`, route table associations, and an internet gateway) with an EC2 web server running Nginx and an optional S3 artifact bucket. The provider switches dynamically between LocalStack for development/CI and real AWS for deployment.

## Why for_each here and count there
- **Subnets use `for_each`**: Subnets are distinct infrastructure components with stable names (`a`, `b`). If key `c` is added, the plan evaluates to "1 to add, 0 to change, 0 to destroy"; removing `a` evaluates to "1 to destroy", leaving subnet `b` completely untouched.
- **The `count` trap on subnets**: Using `count` creates index-based addresses (`[0]`, `[1]`, `[2]`). Removing the middle element causes subsequent indices to shift down by one slot, forcing Terraform to destroy and recreate unchanged subnets simply because their index shifted.
- **Artifact bucket uses `count`**: The S3 bucket is a binary toggle controlled by `create_artifact_bucket`. There are only two possible plans ("0 to add" or "1 to add") with no keys to preserve. As a rule: use `count` when determining *how many*, and `for_each` when determining *which ones*.

## Why not plan and apply against real AWS on every pull request
- **Cost accumulation**: Provisioning real AWS resources on every pull request quickly exhausts the fixed $50 AWS Academy account credit. LocalStack runs locally and in CI service containers at zero cost.
- **Stored credential exposure**: Applying to real AWS requires persistent AWS access keys stored as GitHub secrets. In an AWS Academy Learner Lab, IAM write permissions are blocked (`iam:CreateRole`, `iam:CreateOpenIDConnectProvider`), preventing scoped OIDC roles and forcing the use of broad session credentials.
- **Session expiration flakiness**: Academy Learner Lab sessions expire every few hours. PRs left open overnight fail due to expired session tokens rather than code defects.
- **Execution speed and collisions**: Cloud APIs incur provisioning delays and eventual-consistency latency. Concurrent pull requests also risk resource naming and backend state locking collisions.
- **LocalStack limitations**: LocalStack verifies graph topology and HCL syntax coherence without incurring cloud costs, but it does not evaluate IAM policies or boot actual EC2 virtualization kernels to execute `user_data` scripts.

## Experiments

### Experiment 3: Break only the formatting
- **Prediction**: Adding whitespace indentation before a closing brace in `network.tf` will cause the `gates` job (`terraform fmt -check -recursive`) to fail immediately, preventing the `localstack` service container job from ever running.
- **Observation**: The `gates` job failed in 4 seconds. The downstream `localstack` job was skipped automatically because of `needs: gates`, saving runner minutes.

### Experiment 4: Turn the bucket off
- **Prediction**: Setting `create_artifact_bucket = false` will cause `output "artifact_bucket"` to resolve to `null` via `one()`. If written with `[0].bucket`, Terraform will throw an index error.
- **Observation**: With `one(aws_s3_bucket.artifacts[*].bucket)`, Terraform safely returned `artifact_bucket = null`. Changing it to `[0]` produced an evaluation error because element 0 was missing from an empty tuple.
