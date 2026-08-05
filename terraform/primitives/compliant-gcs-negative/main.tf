# terraform/primitives/compliant-gcs-negative/main.tf  (module block; also include provider + outputs from Step 4)
module "data_bucket" {
  source = "../../modules/compliant-gcs-bucket"

  gcp_project        = "project-5bebb743-d4d1-4629-88b"
  project_label      = "cgep-lab"
  environment        = "prod"
  retention_days     = 30 # FAILS: prod requires >= 365
  bucket_name_suffix = "should-never-exist"
}
