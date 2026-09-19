# Terraform tests

This directory contains native Terraform test cases for the module.

- `basic.tftest.hcl` covers input validation failures and derived secret-name behavior.
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

The smoke test uses `e2e_floci.hcl`, creates and destroys only `aws_vpc.this[0]`, and keeps Terraform state in a temporary directory. It intentionally does not apply the EKS, Kubernetes, or Helm resources because Floci does not provide a Kubernetes control plane.
