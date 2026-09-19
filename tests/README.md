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
