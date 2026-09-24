resource "aws_s3_bucket" "this" {
  for_each = var.enable_s3_buckets ? local.s3_bucket_names : {}

  bucket        = each.value
  force_destroy = var.s3_bucket_force_destroy

  tags = merge(local.tags, {
    Name = each.value
  })
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = var.enable_s3_buckets && var.s3_bucket_versioning_enabled ? local.s3_bucket_names : {}

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = var.enable_s3_buckets ? local.s3_bucket_names : {}

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = var.enable_s3_buckets ? local.s3_bucket_names : {}

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
