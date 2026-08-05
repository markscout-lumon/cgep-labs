# consumers/dev/main.tf
terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

provider "google" {
  project = "project-5bebb743-d4d1-4629-88b"
  region  = "us-central1"
}

module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "project-5bebb743-d4d1-4629-88b"
  project_label      = "cgep-lab"
  environment        = "dev"
  retention_days     = 30
  bucket_name_suffix = "dev-data-mjj"
}

output "attestation" { value = module.data_bucket.compliance_attestation }
output "bucket_url" { value = module.data_bucket.bucket_url }
