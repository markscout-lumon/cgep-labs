# Compliance Policy Library

This directory holds the Policy as Code layer for the `cgep-labs` project. Each `.rego` file encodes a single NIST 800-53 control as an executable rule that reads a Terraform plan and refuses it when the control is violated.

The policies run against `terraform show -json` output, which means they evaluate infrastructure *before* it is provisioned rather than auditing it after the fact. A control that used to live as a sentence in a policy document now runs in under a second, on every change, with no reviewer in the loop. Each deny message names both the offending resource and the control it violates, so the developer who trips the rule can remediate it themselves without opening a GRC ticket.

Every policy carries a `# METADATA` block declaring its control ID, framework, severity, and remediation guidance. That block is machine-readable and auditor-readable at the same time — the policy is simultaneously the enforcement mechanism and the evidence that the control is implemented.

Each policy is backed by unit tests in `tests/`, with both a passing and a failing fixture, so the rules themselves are verified before they are trusted to verify anything else.

## Policies

| Control | File | Severity | What It Requires | Remediation |
|---|---|---|---|---|
| SC-28 | `sc28_encryption.rego` | High | Every `google_storage_bucket` encrypts at rest with a customer-managed encryption key (CMEK). | Add an `encryption { default_kms_key_name = ... }` block referencing a `google_kms_crypto_key` you control. |
| AC-3 | `ac3_no_public.rego` | Critical | Buckets enforce `uniform_bucket_level_access` and `public_access_prevention`; firewall rules do not open ports 22 or 3389 to `0.0.0.0/0`. | Set `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"`. For firewalls, narrow `source_ranges` or remove the rule. |
| CM-6 | `cm6_required_tags.rego` | Medium | Every taggable resource carries the four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. | Add the missing labels to the resource. |

## Test Coverage

| Policy | Tests | Scenarios |
|---|---|---|
| `sc28_encryption.rego` | 2 | Compliant bucket stays silent; bucket with an empty `encryption` array is flagged. |
| `ac3_no_public.rego` | 3 | Locked-down bucket stays silent; public bucket is flagged; firewall opening port 22 to the world is flagged. |
| `cm6_required_tags.rego` | 3 | Fully labeled bucket stays silent; partially labeled bucket is flagged; bucket with no `labels` block at all is flagged. |

Run the suite with:

```bash
opa test -v policies/
```

Evaluate the library against a real plan with:

```bash
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.sc28.deny --format=pretty
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.ac3.deny  --format=pretty
opa eval -d policies -i terraform/primitives/policy-fixture/plan.json data.compliance.cm6.deny  --format=pretty
```

## Lessons Learned

**Remediating the fixture closed the loop.** The test bed in `terraform/primitives/policy-fixture/` ships with one compliant bucket and three broken ones, each broken in exactly one way, plus a wide-open firewall. Fixing each violation and regenerating the plan drove all three deny sets to empty.

**SC-28.** The `bad_no_cmek` bucket had no encryption configuration at all. Adding an `encryption { default_kms_key_name = google_kms_crypto_key.key.id }` block cleared the violation. Worth noting the policy checks that the block *exists* rather than that the key ID is populated: at plan time the KMS key resolves to "known after apply" and is absent from the JSON, so requiring a populated string would wrongly fail correct code.

**AC-3.** This control has two distinct failure modes and the fixture exercises both. The `bad_public` bucket required flipping `uniform_bucket_level_access` from `false` to `true` and changing `public_access_prevention` from `inherited` to `enforced` — the policy requires both conditions, so fixing only one leaves the deny in place. Separately, the `open_ssh` firewall allowed TCP/22 from `0.0.0.0/0`.

**CM-6.** The `bad_no_labels` bucket was missing the `labels` block entirely. Copying the four-label block from the compliant buckets resolved it:

```hcl
labels = {
  project    = "lab33"
  environment = "dev"
  managed_by = "terraform"
  compliance_scope = "cge-p-lab"
}
```

The policy handles the missing-block case explicitly through a second `provided_labels` definition returning an empty set, which is what allows the set subtraction to report all four labels as missing rather than erroring on an undefined field.

**Testing the checker is not the same as checking the infrastructure.** `opa test` runs the policies against hand-built fixtures defined inside the test files and never touches the Terraform plan. It answers "is my rule correct?" `opa eval` points the rules at real plan output and answers "is my infrastructure compliant?"