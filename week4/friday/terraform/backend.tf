# Remote backend: MinIO (S3-compatible), configured per Wednesday's session.
# MinIO does not support native state locking with the S3 backend - this is
# documented as a known limitation in hardening-decisions.md, along with
# what production would use instead (DynamoDB / GCS locking / Consul).
#
# NOTE: syntax below is for AWS provider/Terraform versions where the S3
# backend uses `endpoints = { s3 = ... }` and `use_path_style` (Terraform >= 1.6
# with hashicorp/aws >= 5.x). If your `terraform init` fails on these arguments,
# your version is older - swap to `endpoint` (singular) and `force_path_style`
# instead. Run `terraform version` first and tell me what it prints if unsure.

terraform {
  backend "s3" {
    bucket = "kijanikiosk-tfstate"
    key    = "week4/friday/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = "http://localhost:9000"
    }

    access_key                  = "minioadmin"
    secret_key                  = "minioadmin"
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style               = true
  }
}
