# Lab 3 - Terraform Basics and Your First Pipeline

### Why use OIDC in a real AWS account?
In real account setup, using OpenID Connect (OIDC) lets GitHub Actions to get temporary credentials from AWS STS dynamically for each run rather than relying on creating, managing, and rotating our access key pairs that could potentially leaked.
### Why use session-scoped credentials in this course?
We can't use OIDC in this lab because AWS Academy blocks IAM write permissions like creating identity providers or roles, so we have to use temporary Vocareum session keys instead.
