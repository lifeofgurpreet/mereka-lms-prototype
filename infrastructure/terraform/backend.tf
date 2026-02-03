# Remote state storage in GCS
#
# Before first use, create the bucket:
#   gsutil mb -p mereka-lms -l asia-southeast1 gs://mereka-lms-terraform-state
#   gsutil versioning set on gs://mereka-lms-terraform-state

terraform {
  backend "gcs" {
    bucket = "mereka-lms-terraform-state"
    prefix = "mereka-lms"
  }
}
