# CGE-P Curriculum

A run through the [GRC Engineering Academy](https://grcengclub.com)'s CGE-P curriculum, built as one
repository rather than a folder of exercises. Live write-up: [markjanowski.dev/projects/cgep-curriculum](https://markjanowski.dev/projects/cgep-curriculum).

The labs build on each other, so they share one repository instead of eleven. Each lab adds a layer
to the same body of work rather than starting over: the infrastructure comes first, then the evidence
that it was compliant, then the policies that refuse it when it is not, then the pipeline that runs all
of that on every change.

**Status: 8 of 11 labs merged**, through Chapter 5 (AWS Security Services Baseline).

## What is built

| Lab | What it adds |
| --- | --- |
| [2.3](terraform/primitives/compliant-s3) | An S3 primitive that is compliant in the same apply that creates it — encryption, versioning, a full public access block, and access logging to a dedicated log bucket. |
| [2.4](terraform/modules/compliant-gcs-bucket) | The same idea as a reusable GCP module: CMEK on a rotating KMS key, uniform bucket-level access, public access prevention, and a retention floor that fails the plan below 365 days in production. |
| [2.5](terraform/primitives/evidence-vault) | A write-once evidence vault on S3 Object Lock, plus a capture script that snapshots the plan, state, commit, and tool versions, hashes each with SHA-256, and returns a signed receipt. |
| [3.3](policies) | Three NIST 800-53 controls as OPA policies that read a Terraform plan and deny it before apply, each carrying machine-readable METADATA and its own unit tests. |
| [3.4](policies) | AWS variants of those policies, organized by control rather than by cloud, behind a Conftest gate that writes its results as evidence and exits non-zero on a violation. |
| [4.3](.github/workflows/grc-gate.yml) | The gate wired into GitHub Actions on every pull request — Terraform plan, Conftest policy check, and a Trivy config scan — running on short-lived OIDC credentials instead of static AWS keys. |
| [4.4](scripts/capture-evidence.sh) | Cosign keyless signing of the evidence bundle, plus a verification script, so a receipt can be checked by someone who doesn't trust the machine that produced it — closing the chain of custody from plan to signed evidence. |
| [5.2](terraform/baselines/aws) | An always-on AWS baseline: a multi-region CloudTrail with log-file validation for tamper-evident audit records, and Security Hub subscribed to the NIST 800-53 and AWS FSBP standards for continuous findings. |

The through-line is that a control which lives in a document is a control somebody has to remember.
Everything here is an attempt to move one control from that state into something that runs on its own
and leaves a record behind.

## Repo layout

```
terraform/
  primitives/     # single-resource labs (2.3, 2.5) and GCP test fixtures
  modules/        # reusable modules (2.4)
  baselines/      # account-level, always-on infra (5.2)
policies/         # Rego policy library (3.3, 3.4), with tests/ and its own README
scripts/          # policy-gate.sh, capture-evidence.sh, verify-evidence.sh
.github/workflows/grc-gate.yml  # the CI gate (4.3, 4.4)
evidence/         # captured evidence per lab, one folder per lab number
```

## Running it

Policy unit tests:

```bash
opa test -v policies/
```

Run the AWS policy gate against a saved plan (writes results to `evidence/lab-3-4/`):

```bash
bash scripts/policy-gate.sh --workspace terraform/primitives/compliant-s3
```

Capture and sign evidence for a workspace, then verify the chain of custody:

```bash
bash scripts/capture-evidence.sh --workspace <path> --run-id <id> --vault <bucket>
bash scripts/verify-evidence.sh <run-id> --vault <bucket>
```

The full gate — plan, Conftest, Trivy, evidence capture, Cosign signing — runs on every pull request via
[`grc-gate.yml`](.github/workflows/grc-gate.yml), using OIDC-assumed AWS credentials rather than static
keys.

See [`policies/README.md`](policies/README.md) for the control-by-control policy reference and
[`terraform/baselines/aws/README.md`](terraform/baselines/aws/README.md) for the AWS baseline's control
mapping.

## What is ahead

- **5.4** — the GCP half of the security baseline: Org Policy constraints and Workload Identity
  Federation in place of service account keys.
- **6.1** — expressing the control mappings as OSCAL, so the output is a format an assessor's tooling
  can read instead of a table in a README.
- **Capstone** — a 30-day project applying all of it to make a fictional company's Patient Intake API
  audit-defensible without slowing engineering down.
