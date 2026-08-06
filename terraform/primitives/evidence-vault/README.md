This lab 2.5 "IaC as Compliance Evidence" is a great reminder of the capabilities of GRC Engineering. Controls can be built into infrastructure and proven but how do you show your work, including timestamping it and storing it in a tamper proof location.

Through this lab, I learned how to create a hardened S3 bucket evidence vault that can't be deleted by anyone besides me, and ran a script that reads the plan, state file, and more to produce a piece of concrete zipped evidence that auditors can use.

Lab 2.5 - IaC as Compliance Evidence

Lab 2.5 is a good reminder of what GRC Engineering is capable of. Controls can be built into infrastructure and proven from the code itself. But building the control is only half the job, the other half is showing your work: timestamping it, hashing it, and putting it in a tamperproof storage location.

Having built buckets in the earlier labs, this one went faster. 

What I built

An evidence vault — a hardened S3 bucket with Object Lock, versioning, SSE, a full public access block, and a bucket policy denying s3:DeleteBucket to everyone except account root. Object Lock has to be enabled at bucket creation; there's no retrofitting it.

capture-evidence.sh — reads a live Terraform workspace and pulls the plan, state, git commit, and Terraform version. Hashes each file into a SHA-256 manifest, zips the bundle, uploads it to the vault, and prints a JSON receipt with the version_id.

What I'm taking from it

As an auditor, a screenshot tells me someone once saw a screen. A hashed, timestamped plan locked in a vault tells me integrity, attribution, and reproducibility. 

Artifacts
terraform/primitives/evidence-vault/
scripts/capture-evidence.sh
evidence/lab-2-5/receipt.json

