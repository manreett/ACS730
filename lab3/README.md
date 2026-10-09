# Lab 3 - Terraform Basics and  First Pipeline

### Why use OIDC in a real AWS account?
In real account setup, using OpenID Connect (OIDC) lets GitHub Actions to get temporary credentials from AWS STS dynamically for each run rather than relying on creating, managing, and rotating our access key pairs that could potentially leaked.

### Why use session-scoped credentials in this course?
We can't use OIDC in this lab because AWS Academy blocks IAM write permissions like creating identity providers or roles, so we have to use temporary Vocareum session keys instead.


## Operational
- **ExpiredToken / InvalidClientTokenId**: This happens when the Vocareum lab session expires. In order to resolve it, initiate a new lab session in Vocareum, and execute `./scripts/refresh-gha-creds.sh manreett/ACS730` followed by running the failing workflow again. There is no need for changes in the code in the repository.
- **Input required and not supplied: aws-region**: This occurs due to the absence of `AWS_REGION` in the GitHub repository variable. This problem can be fixed using `refresh-gha-creds.sh` or `gh variable set AWS_REGION --body us-east-1`.

## Terraform Version
- Terraform version used: 1.10.3

## Experiments

### Experiment 1: Credential Expiry
- **Prediction**:If the Vocareum session time expires or the lab is ended ,there will be failure of the credential creation or aws sts get-caller-identity phase with ExpiredToken exception.
- **Observation**: The re-run of the workflow after the session completion led to STS token authentication failure with the `ExpiredToken` error. The use of `refresh-gha-creds.sh` after initiating a new session resolved the problem without changing anything in the repositories.

### Experiment 2: State File Locking and Concurrency
- **Prediction**: If `cancel-in-progress` was set to `true`, and multiple commits were made, a `terraform apply` could be interrupted midway, potentially causing orphaned cloud resources or state lock problems.
- **Observation**: Unlike automated test , `terraform apply` must run sequentially to completion . Without concurrency groups, `use_lockfile` in S3 rejects concurrent apply operations to prevent state corruption.

