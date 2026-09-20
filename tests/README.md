# Terraform tests

This directory contains native Terraform test cases for the module.

- `basic.tftest.hcl` covers input validation failures and derived secret-name behavior.
- `e2e_floci.tftest.hcl` applies and destroys only `aws_vpc.this[0]` against a local Floci endpoint.
- The tests use mocked providers so they can run without live AWS, Kubernetes, or Helm credentials.

Run the suite from the repository root:

```bash
terraform init
terraform test
```

> Note: mocked provider support requires a Terraform release that includes `mock_provider` in native tests.

## Floci integration smoke test

Run a local Floci instance and test the module's VPC resource against its AWS-compatible endpoint:

```bash
docker compose -f docker-compose.floci.yml up -d
bash tests/run-floci.sh
docker compose -f docker-compose.floci.yml down
```

`bash tests/run-floci.sh` checks Floci health, sets the required AWS/endpoint environment variables, and then runs:

```bash
terraform init -backend=false -input=false
terraform test tests/e2e_floci.tftest.hcl
```

The smoke test uses `e2e_floci.tftest.hcl`, applies only `aws_vpc.this[0]`, and relies on Terraform test's test-run cleanup for created resources. It intentionally does not apply the EKS, Kubernetes, or Helm resources because Floci does not provide a Kubernetes control plane.
