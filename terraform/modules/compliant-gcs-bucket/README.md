# Compliant GCS Bucket with Customer-Managed Encryption

## Overview

This project definitely proved more difficult than the first. Up to this point I have had no experience with GCP, so it took a bit of figuring out to even get the `gcloud` CLI configured. From there, it seemed there were a lot of similarities to the first lab. The big differences were building different controls into the bucket and using a self-managed key for encryption.

## Controls Enforced

| Control | What it means in plain terms | Where the module enforces it |
|---|---|---|
| **SC-12** | You establish and own the encryption key, rather than letting the provider hold it. | `google_kms_key_ring` + `google_kms_crypto_key` |
| **SC-13 / SC-28** | Data is encrypted at rest with that key (a CMEK), and the key rotates. | `encryption {}` block + `rotation_period` |
| **AC-3** | Access is uniform and the public can't reach the bucket. | `uniform_bucket_level_access` + `public_access_prevention` |
| **AU-11** | Records are retained for a set period. | `retention_policy` |
| **CM-6** | Required labels are present and can't be dropped. | Merged labels |

## Approach

Almost all of the resources were already written up, so it was more about reading through each file and understanding what each one did, then figuring out where to add my own input (in the form of my Google project ID and bucket suffix).

## What Stood Out

### 1. Environment-aware retention periods

The two parts I found most interesting about this lab — the first being how retention periods can be defined differently for resources in different environments:

```hcl
variable "retention_days" {
  type        = number
  description = "Object retention in days. Production must be >= 365."

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 3650
    error_message = "retention_days must be between 1 and 3650."
  }

  validation {
    condition     = var.environment != "prod" || var.retention_days >= 365
    error_message = "retention_days must be >= 365 when environment == \"prod\"."
  }
}
```

> The second validation block is the interesting one: it lets a non-production bucket use a short retention period while making a production bucket fail at plan time if it drops below a year. The control requirement is enforced by the code rather than by a reviewer catching it later.

### 2. A human-readable compliance attestation

The second being the output file, and seeing how an attestation can be produced as a source of evidence that is genuinely human readable:

```hcl
output "compliance_attestation" {
  description = "Computed attestation of the controls this module enforces."
  value = {
    encryption_algorithm     = "google-managed-cmek-aes256"
    versioning_enabled       = google_storage_bucket.bucket.versioning[0].enabled
    public_access_prevention = google_storage_bucket.bucket.public_access_prevention
    uniform_access_enforced  = google_storage_bucket.bucket.uniform_bucket_level_access
    retention_period_days    = var.retention_days
    required_labels_present = alltrue([
      for k in keys(local.required_labels) : contains(keys(google_storage_bucket.bucket.labels), k)
    ])
    kms_rotation_period = google_kms_crypto_key.key.rotation_period
  }
}
```

## Takeaway

I am looking forward to seeing how this attestation can be used as a machine-readable artifact to further enforce the need for GRC engineering.