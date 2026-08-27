provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_project_service" "storage" {
  count              = var.enable_project_services ? 1 : 0
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

resource "google_storage_bucket" "terraform_state" {
  name                     = var.state_bucket_name
  location                 = var.region
  force_destroy            = false
  public_access_prevention = "inherited"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [
    google_project_service.storage,
  ]
}

resource "google_storage_bucket_iam_member" "public_tfstate_viewer" {
  bucket = google_storage_bucket.terraform_state.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

output "state_bucket_name" {
  value = google_storage_bucket.terraform_state.name
}
