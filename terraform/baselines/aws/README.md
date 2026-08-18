# AWS Security Services Baseline

Account-level security baseline for the CGE-P lab environment.
Deploys the always-on AWS services that produce continuous compliance evidence.

## Control mapping

| Control | Title | Implementation | Status |
|---|---|---|---|
| **AU-2** | Event Logging | CloudTrail `cgep-lab-mgmt` captures management events across all regions | Implemented |
| **AU-12** | Audit Record Generation | Multi-region trail with `include_global_service_events`, delivering to S3 | Implemented |
| **AU-9** | Protection of Audit Information | `enable_log_file_validation` produces signed hourly digests; bucket has SSE, public access block, and a bucket policy scoped by `aws:SourceArn` | Implemented |
| **AU-10** | Non-repudiation | Digest files signed by an AWS-managed key allow after-the-fact detection of log tampering | Implemented |
| **RA-5** | Vulnerability Monitoring and Scanning | Security Hub NIST 800-53 Rev 5 and AWS FSBP standards run continuous automated checks | Implemented |
| **SI-4** | System Monitoring | Security Hub aggregates and normalizes findings account-wide | Partially implemented — GuardDuty not enabled, so coverage is limited to native checks |
| **CM-2** | Baseline Configuration | AWS Config resource recorder | Not implemented |
| **CM-6** | Configuration Settings | AWS Config rule evaluations | Not implemented |
| **CM-8** | System Component Inventory | AWS Config resource inventory over time | Not implemented |

**AU-9 vs AU-10.** Log-file validation is mapped to both: the signed digest chain protects the
integrity of audit records (AU-9) and provides the cryptographic basis for attributing actions to a
principal without repudiation (AU-10). Naming both makes the reasoning explicit rather than assumed.

**CM-2 / CM-6 / CM-8.** AWS Config is intentionally excluded for cost (~$2/month per recorder). This
account is standalone — no organization, therefore no SCP blocking it. The gap is self-documenting:
Security Hub raises a CRITICAL `Config.1` finding ("AWS Config should be enabled and use the
service-linked role for resource recording") that appears in the captured evidence, so these controls
are recorded as known gaps with machine-generated support rather than silently omitted.

## Evidence

`evidence/lab-5-2/security-hub-findings.json` — captured `<DATE>`, `<COUNT>` findings.
Vault `VersionId`: `<VERSION_ID>`