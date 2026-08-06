# Lab 2.5 — IaC as Compliance Evidence

Lab 2.5 is a good reminder of what GRC Engineering is capable of. Controls can be built into infrastructure and proven from the code itself. But building the control is only half the job, the other half is showing your work: timestamping it, hashing it, and putting it in tamperproof storage.

Having built buckets in the earlier labs, this one went faster.

---

## What I built

### Evidence vault

A hardened S3 bucket:

- **Object Lock** — has to be enabled at bucket creation, there's no retrofitting it
- **Versioning** — required by Object Lock
- **SSE encryption** and a full **public access block**
- **Bucket policy** denying `s3:DeleteBucket` to everyone except account root

### `capture-evidence.sh`

Reads a live Terraform workspace and pulls:

| Artifact | Source |
|---|---|
| `plan.json` | `terraform show -json tfplan` |
| `state.json` | `terraform state pull` |
| `commit.txt` | `git log -1 --pretty=full` |
| `version.txt` | `terraform version` |

It hashes each file into a SHA-256 manifest, bundles them, uploads to the vault, and prints a JSON receipt with the `version_id`:

```json
{"run_id":"test-001","vault":"cgep-lab-grc-evidence-vault-XXXXXXXX","key":"runs/test-001/bundle.tar.gz","version_id":"<version-id>","captured_at_utc":"<timestamp>"}
```

---

## What I'm taking from it

As an auditor, I can tell from a screenshot that someone once saw a screen. A hashed, timestamped plan locked in a vault tells me integrity, attribution, and reproducibility.

---

## Artifacts

```
terraform/primitives/evidence-vault/
scripts/capture-evidence.sh
evidence/lab-2-5/receipt.json
```
