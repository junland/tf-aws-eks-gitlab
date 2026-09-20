# Terraform tests

This directory contains native Terraform test cases for the module.

- `basic.tftest.hcl` covers input validation failures and derived secret-name behavior.
- `e2e_floci.tftest.hcl` applies only `aws_vpc.this[0]` against a local Floci endpoint, validates the `create_vpc = false` plan path, and includes a targeted cleanup apply run.
- The tests use mocked providers so they can run without live AWS, Kubernetes, or Helm credentials.

Run the suite from the repository root:

```bash
terraform init
terraform test
```

> Note: mocked provider support requires a Terraform release that includes `mock_provider` in native tests.

## Floci integration smoke test

### External dependency setup module

`tests/setup/` is a Terraform helper module only:

- `tests/setup/main.tf`
- `tests/setup/outputs.tf`

It centralizes prerequisite configuration values used by integration tests (PostgreSQL and S3-compatible settings).

### Floci emulator smoke run

Run a local Floci instance and test the module's VPC resource against its AWS-compatible endpoint:

```bash
docker compose -f docker-compose.floci.yml up -d
bash tests/run-floci.sh
docker compose -f docker-compose.floci.yml down
```

`bash tests/run-floci.sh` checks Floci health, sets the required AWS/endpoint environment variables, creates a temporary `TF_DATA_DIR` for isolation, and then runs from the repository root:

```bash
terraform init -backend=false -input=false
terraform test -input=false tests/e2e_floci.tftest.hcl
```

The smoke test uses `e2e_floci.tftest.hcl`, applies only `aws_vpc.this[0]`, includes a follow-up full plan run with external-network inputs to validate the configuration path where `create_vpc = false`, and then runs a targeted cleanup apply to remove the managed VPC resource. It intentionally does not apply the EKS, Kubernetes, or Helm resources because Floci does not provide a Kubernetes control plane.
