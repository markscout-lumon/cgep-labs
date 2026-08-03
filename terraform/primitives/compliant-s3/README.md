# First Compliant Resource

**Lab 2.3 — CGE-P**

This module enforces SC-28, AU-3, AU-6, CM-6, and AC-3 on a single S3 bucket.

This was performed by creating a series of resources in AWS using Terraform HCL, an infrastructure as code tool. The NIST 800-53 controls are enforced in the ways described below in the `main.tf` file.

---

## Control Mapping

| Control | Requirement | Enforcing Resource |
|---|---|---|
| **SC-28** | Protection of information at rest | `aws_s3_bucket_server_side_encryption_configuration` |
| **CM-6** | Configuration settings / recoverability | `aws_s3_bucket_versioning` |
| **AC-3** | Access enforcement | `aws_s3_bucket_public_access_block` |
| **AU-3** | Content of audit records | `aws_s3_bucket_logging` |
| **AU-6** | Audit record review | `aws_s3_bucket_logging` |

---

## Implementation

### SC-28 — Protection of information at rest

Server-side encryption using AES-256.

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### CM-6 — Configuration settings

Versioning preserves prior object states for recovery and audit.

```hcl
resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}
```

### AC-3 — Access enforcement

Explicit deny on every public access vector.

```hcl
resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### AU-3 / AU-6 — Content of audit records and audit review

> **Note:** Most of these resources are for the log bucket, with the primary bucket pointed at the log bucket in the last resource. All controls applicable to the primary also apply here, besides logging the logging bucket.

**Log bucket creation:**

```hcl
resource "aws_s3_bucket" "log" {
  bucket = local.log_name
}
```

**Ownership controls and ACL** — required for S3 log delivery:

```hcl
resource "aws_s3_bucket_ownership_controls" "log" {
  bucket = aws_s3_bucket.log.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "log" {
  depends_on = [aws_s3_bucket_ownership_controls.log]
  bucket     = aws_s3_bucket.log.id
  acl        = "log-delivery-write"
}
```

**SC-28 and AC-3 applied to the log bucket:**

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "log" {
  bucket = aws_s3_bucket.log.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_public_access_block" "log" {
  bucket                  = aws_s3_bucket.log.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Pointing the primary bucket at the log bucket:**

```hcl
resource "aws_s3_bucket_logging" "primary" {
  bucket        = aws_s3_bucket.primary.id
  target_bucket = aws_s3_bucket.log.id
  target_prefix = "access-logs/"
}
```

---

## Inputs

S3 buckets created using this code are required to have:

- **Project name**
- **Environment** — one of `dev`, `staging`, or `prod`
- **Project suffix** — if no suffix is given, it defaults to a random ID with a byte length of 4

---

## Evidence Generation

```bash
terraform plan -out=tfplan
```

Piping the plan to the evidence folder outside of this lab produces a hard copy of what was deployed to AWS. That file is the machine-readable compliance evidence we set out to read in future labs.