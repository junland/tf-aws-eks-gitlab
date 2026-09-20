#!/usr/bin/env bash

set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
terraform_bin=${TERRAFORM_BIN:-terraform}
floci_endpoint=${FLOCI_ENDPOINT:-http://127.0.0.1:4566}

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_REGION=us-east-1
export AWS_EC2_METADATA_DISABLED=true
export AWS_ENDPOINT_URL_EC2="$floci_endpoint"
export AWS_ENDPOINT_URL_STS="$floci_endpoint"

curl --fail --silent --show-error "$floci_endpoint/health" >/dev/null

"$terraform_bin" -chdir="$repo_root" init -backend=false -input=false
"$terraform_bin" -chdir="$repo_root" test tests/e2e_floci.tftest.hcl
