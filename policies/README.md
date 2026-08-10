# Compliance Policy Library

This directory holds the Policy as Code layer for the `cgep-labs` project. Each
`.rego` file encodes a single NIST 800-53 control as an executable rule that
reads a Terraform plan and refuses it when the control is violated.

The policies run against `terraform show -json` output, which means they
evaluate infrastructure *before* it is provisioned rather than auditing it after
the fact. A control that used to live as a sentence in a policy document now
runs in under a second, on every change, with no reviewer in the loop. Each deny
message names both the offending resource and the control it violates, so the
developer who trips the rule can remediate it themselves without opening a GRC
ticket.

The library is organized **by control, not by cloud**. Three control IDs are
covered — SC-28, AC-3, and CM-6 — each implemented twice, once for GCP and once
for AWS. A control ID is portable across providers; a Rego rule that hardcodes
`google_storage_bucket` is not. Keeping the control ID constant while varying
the implementation is what lets one control statement map to evidence from
either cloud.

Every policy carries a `# METADATA` block declaring its control ID, framework,
severity, and remediation guidance. That block is machine-readable and
auditor-readable at the same time — the policy is simultaneously the
enforcement mechanism and the evidence that the control is implemented.

## Policies

| Control | Cloud | File | Severity | What It Requires |
| --- | --- | --- | --- | --- |
| SC-28 | GCP | `sc28_encryption.rego` | High | Every `google_storage_bucket` encrypts at rest with a customer-managed encryption key (CMEK). |
| SC-28 | AWS | `sc28_encryption_aws.rego` | High | Every `aws_s3_bucket` has an `aws_s3_bucket_server_side_encryption_configuration` referencing it. |
| AC-3 | GCP | `ac3_no_public.rego` | Critical | Buckets enforce `uniform_bucket_level_access` and `public_access_prevention`; firewalls do not open ports 22 or 3389 to `0.0.0.0/0`. |
| AC-3 | AWS | `ac3_no_public_aws.rego` | Critical | Every `aws_s3_bucket` has an `aws_s3_bucket_public_access_block` with all four flags set to `true`. |
| CM-6 | GCP | `cm6_required_tags.rego` | Medium | Every taggable resource carries the four required labels: `project`, `environment`, `managed_by`, `compliance_scope`. |
| CM-6 | AWS | `cm6_required_tags_aws.rego` | Medium | Every taggable resource carries the four required tags: `Project`, `Environment`, `ManagedBy`, `ComplianceScope`. |

## Remediation

| Control | Cloud | Remediation |
| --- | --- | --- |
| SC-28 | GCP | Add an `encryption { default_kms_key_name = ... }` block referencing a `google_kms_crypto_key` you control. |
| SC-28 | AWS | Add `aws_s3_bucket_server_side_encryption_configuration { bucket = aws_s3_bucket.<name>.id ... }` for the bucket. |
| AC-3 | GCP | Set `uniform_bucket_level_access = true` and `public_access_prevention = "enforced"`. For firewalls, narrow `source_ranges` or remove the rule. |
| AC-3 | AWS | Add an `aws_s3_bucket_public_access_block` for the bucket with all four flags `true`. |
| CM-6 | GCP | Add the missing labels to the resource. |
| CM-6 | AWS | Add the missing tags to the resource, or set them once via provider `default_tags`. |

## Namespaces

Each policy declares its own package, which is what Conftest targets with
`--namespace`. The string must match the `package` declaration character for
character or Conftest silently finds no rules to run.

| File | Package |
| --- | --- |
| `sc28_encryption.rego` | `compliance.sc28` |
| `sc28_encryption_aws.rego` | `compliance.sc28_aws` |
| `ac3_no_public.rego` | `compliance.ac3` |
| `ac3_no_public_aws.rego` | `compliance.ac3_aws` |
| `cm6_required_tags.rego` | `compliance.cm6` |
| `cm6_required_tags_aws.rego` | `compliance.cm6_aws` |

## Test Coverage

Unit tests live in `tests/` and cover the GCP variants, with both a passing and
a failing fixture for each rule.

| Policy | Tests | Scenarios |
| --- | --- | --- |
| `sc28_encryption.rego` | 2 | Compliant bucket stays silent; bucket with an empty `encryption` array is flagged. |
| `ac3_no_public.rego` | 3 | Locked-down bucket stays silent; public bucket is flagged; firewall opening port 22 to the world is flagged. |
| `cm6_required_tags.rego` | 3 | Fully labeled bucket stays silent; partially labeled bucket is flagged; bucket with no `labels` block at all is flagged. |

The AWS variants are exercised end to end instead, by running the gate against a
compliant plan and against a deliberately broken copy of the same code.

## Running the Library

Unit tests:

```bash
opa test -v policies/
```

Ad-hoc evaluation against a GCP plan:

```bash
PLAN=terraform/primitives/policy-fixture/plan.json

opa eval -d policies -i "$PLAN" data.compliance.sc28.deny --format=pretty
opa eval -d policies -i "$PLAN" data.compliance.ac3.deny --format=pretty
opa eval -d policies -i "$PLAN" data.compliance.cm6.deny --format=pretty
```

The CI gate, which evaluates every AWS namespace and exits non-zero on any
violation:

```bash
bash scripts/policy-gate.sh --workspace terraform/primitives/compliant-s3
```

## Lessons Learned

**Remediating the fixture closed the loop.** The GCP test bed in
`terraform/primitives/policy-fixture/` ships with one compliant bucket and three
broken ones, each broken in exactly one way, plus a wide-open firewall. Fixing
each violation and regenerating the plan drove all three deny sets to empty.

**SC-28 (GCP).** The `bad_no_cmek` bucket had no encryption configuration at
all. Adding an encryption block referencing
`google_kms_crypto_key.key.id` cleared the violation. Worth noting the policy
checks that the block *exists* rather than that the key ID is populated: at plan
time the KMS key resolves to "known after apply" and is absent from the JSON, so
requiring a populated string would wrongly fail correct code.

**AC-3 (GCP).** This control has two distinct failure modes and the fixture
exercises both. The `bad_public` bucket required flipping
`uniform_bucket_level_access` from `false` to `true` and changing
`public_access_prevention` from `inherited` to `enforced` — the policy requires
both conditions, so fixing only one leaves the deny in place. Separately, the
`open_ssh` firewall allowed TCP/22 from `0.0.0.0/0`.

**CM-6 (GCP).** The `bad_no_labels` bucket was missing the `labels` block
entirely. Copying the four-label block from the compliant buckets resolved it:

```hcl
labels = {
  project          = "lab33"
  environment      = "dev"
  managed_by       = "terraform"
  compliance_scope = "cge-p-lab"
}
```

The policy handles the missing-block case explicitly through a second
`provided_labels` definition returning an empty set, which is what allows the
set subtraction to report all four labels as missing rather than erroring on an
undefined field.

**A green result is not the same as a covered one.** Running the GCP policies
against an AWS plan returns zero failures — not because the infrastructure is
compliant, but because the rules look for resource types that do not exist in
that plan. Nothing matched, so nothing was checked. This empty pass is
indistinguishable from a real pass in the output, which makes it the most
dangerous failure mode in Policy as Code. It is the reason the library carries
per-cloud variants and the reason `policy-gate.sh` invokes only the AWS
namespaces when evaluating an AWS plan.

**Match by reference on AWS, not by value.** On GCP, encryption is a block
inside the bucket. On AWS it is a separate resource that points back at the
bucket, and at plan time the bucket name is still unknown because the
`random_id` suffix has not been generated. The AWS SC-28 rule therefore reads
`configuration.root_module.resources[].expressions.bucket.references`, which
holds wiring strings like `aws_s3_bucket.primary.id`, and asks "is an encryption
resource attached to this bucket?" rather than "do these names match?" Only the
first question is answerable before apply.

**The plan JSON has two halves and they hold different kinds of fact.**
`configuration` holds the wiring — which resource references which — and is
fully known at plan time. `planned_values` holds resolved values, some of which
are still unknown. The AWS AC-3 rule reads both: `configuration` to find which
public-access-block belongs to which bucket, and `planned_values` to read the
four boolean flags, which are literals and therefore always present. Knowing
which half answers which question is most of the skill in writing plan
policies.

**Multiple rule definitions replace conditional ladders.** The AWS CM-6 rule
defines `tag_keys` three times: once for `tags_all` (present when provider
`default_tags` is in use), once for a bare `tags` block, and once returning an
empty set when neither exists. Rego selects whichever definition matches rather
than evaluating an if-else chain, which is how a policy degrades gracefully
instead of erroring on an undefined field.

**Testing the checker is not the same as checking the infrastructure.**
`opa test` runs the policies against hand-built fixtures defined inside the test
files and never touches the Terraform plan. It answers "is my rule correct?"
`opa eval` and `conftest` point the rules at real plan output and answer "is my
infrastructure compliant?" A rule with a typo in the resource type passes the
second question trivially while failing the first.
