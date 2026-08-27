provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  name_prefix           = "${var.resource_prefix}-${var.environment}"
  dataset_id            = replace("${var.resource_prefix}_${var.environment}", "-", "_")
  image_bucket_name     = "${var.resource_prefix}-${var.project_id}-${var.environment}-images"
  bulk_bucket_name      = "${var.resource_prefix}-${var.project_id}-${var.environment}-bulk"
  image_uri             = "${var.region}-docker.pkg.dev/${var.project_id}/${var.artifact_repository_id}/${var.image_name}:${var.image_tag}"
  submissions_table_id  = "${var.project_id}.${local.dataset_id}.form_submissions"
  calls_table_id        = "${var.project_id}.${local.dataset_id}.call_attempts"
  bulk_uploads_table_id = "${var.project_id}.${local.dataset_id}.bulk_uploads"
}

resource "google_project_service" "services" {
  for_each = var.enable_project_services ? toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "cloudbuild.googleapis.com",
    "dataflow.googleapis.com",
    "run.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ]) : toset([])

  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker" {
  location      = var.region
  repository_id = var.artifact_repository_id
  description   = "Docker images for Habi form services"
  format        = "DOCKER"

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_project_iam_member" "cloudbuild_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${data.google_project.current.number}@cloudbuild.gserviceaccount.com"

  depends_on = [
    google_project_service.services,
  ]
}

resource "null_resource" "cloud_build_image" {
  count = var.run_cloud_build ? 1 : 0

  triggers = {
    image_uri = local.image_uri
  }

  provisioner "local-exec" {
    command = "gcloud builds submit ../app --config ../app/cloudbuild.yaml --project ${var.project_id} --substitutions _REGION=${var.region},_AR_REPOSITORY=${var.artifact_repository_id},_IMAGE_NAME=${var.image_name},_IMAGE_TAG=${var.image_tag}"
  }

  depends_on = [
    google_artifact_registry_repository.docker,
  ]
}

resource "google_storage_bucket" "images" {
  name                     = local.image_bucket_name
  location                 = var.region
  force_destroy            = false
  public_access_prevention = "inherited"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_storage_bucket_iam_member" "public_images_viewer" {
  bucket = google_storage_bucket.images.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

resource "google_storage_bucket" "bulk" {
  name          = local.bulk_bucket_name
  location      = var.region
  force_destroy = false

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_bigquery_dataset" "habi" {
  dataset_id                 = local.dataset_id
  location                   = "US"
  delete_contents_on_destroy = false

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_bigquery_table" "form_submissions" {
  dataset_id          = google_bigquery_dataset.habi.dataset_id
  table_id            = "form_submissions"
  deletion_protection = true

  schema = file("${path.module}/schemas/form_submissions.json")
}

resource "google_bigquery_table" "call_attempts" {
  dataset_id          = google_bigquery_dataset.habi.dataset_id
  table_id            = "call_attempts"
  deletion_protection = true

  schema = file("${path.module}/schemas/call_attempts.json")
}

resource "google_bigquery_table" "bulk_uploads" {
  dataset_id          = google_bigquery_dataset.habi.dataset_id
  table_id            = "bulk_uploads"
  deletion_protection = true

  schema = file("${path.module}/schemas/bulk_uploads.json")
}

resource "google_pubsub_topic" "submissions" {
  name = "${local.name_prefix}-submissions"

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_service_account" "app" {
  account_id   = "${local.name_prefix}-app"
  display_name = "Habi form app Cloud Run service account"
}

resource "google_service_account" "worker" {
  account_id   = "${local.name_prefix}-worker"
  display_name = "Habi fake call worker Cloud Run service account"
}

resource "google_service_account" "dataflow" {
  account_id   = "${local.name_prefix}-dataflow"
  display_name = "Habi bulk phone Dataflow service account"
}

resource "google_service_account" "pubsub_push" {
  account_id   = "${local.name_prefix}-push"
  display_name = "Pub/Sub push invoker service account"
}

resource "google_project_service_identity" "pubsub" {
  provider = google-beta
  project  = var.project_id
  service  = "pubsub.googleapis.com"

  depends_on = [
    google_project_service.services,
  ]
}

resource "google_service_account_iam_member" "pubsub_token_creator" {
  service_account_id = google_service_account.pubsub_push.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_project_service_identity.pubsub.email}"
}

resource "google_storage_bucket_iam_member" "app_images" {
  bucket = google_storage_bucket.images.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket_iam_member" "app_bulk_writer" {
  bucket = google_storage_bucket.bulk.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_storage_bucket_iam_member" "dataflow_bulk_admin" {
  bucket = google_storage_bucket.bulk.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_bigquery_dataset_iam_member" "app_bq_editor" {
  dataset_id = google_bigquery_dataset.habi.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.app.email}"
}

resource "google_bigquery_dataset_iam_member" "worker_bq_editor" {
  dataset_id = google_bigquery_dataset.habi.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.worker.email}"
}

resource "google_bigquery_dataset_iam_member" "dataflow_bq_editor" {
  dataset_id = google_bigquery_dataset.habi.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_pubsub_topic_iam_member" "app_publisher" {
  topic  = google_pubsub_topic.submissions.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.app.email}"
}

resource "google_pubsub_topic_iam_member" "dataflow_publisher" {
  topic  = google_pubsub_topic.submissions.name
  role   = "roles/pubsub.publisher"
  member = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_project_iam_member" "app_dataflow_developer" {
  project = var.project_id
  role    = "roles/dataflow.developer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

resource "google_service_account_iam_member" "app_can_run_dataflow_as_worker" {
  service_account_id = google_service_account.dataflow.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.app.email}"
}

resource "google_project_iam_member" "dataflow_worker" {
  project = var.project_id
  role    = "roles/dataflow.worker"
  member  = "serviceAccount:${google_service_account.dataflow.email}"
}

resource "google_cloud_run_v2_service" "app" {
  name     = "${local.name_prefix}-app"
  location = var.region

  template {
    service_account = google_service_account.app.email

    containers {
      image = local.image_uri

      ports {
        container_port = 8080
      }

      env {
        name  = "IMAGE_BUCKET"
        value = google_storage_bucket.images.name
      }
      env {
        name  = "BQ_SUBMISSIONS_TABLE"
        value = local.submissions_table_id
      }
      env {
        name  = "BQ_CALL_ATTEMPTS_TABLE"
        value = local.calls_table_id
      }
      env {
        name  = "BQ_BULK_UPLOADS_TABLE"
        value = local.bulk_uploads_table_id
      }
      env {
        name  = "PUBSUB_TOPIC"
        value = google_pubsub_topic.submissions.id
      }
      env {
        name  = "BULK_UPLOAD_BUCKET"
        value = google_storage_bucket.bulk.name
      }
      env {
        name  = "DATAFLOW_ENABLED"
        value = tostring(var.enable_dataflow_runner)
      }
      env {
        name  = "DATAFLOW_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "DATAFLOW_REGION"
        value = var.region
      }
      env {
        name  = "DATAFLOW_TEMP_LOCATION"
        value = "gs://${google_storage_bucket.bulk.name}/dataflow/temp"
      }
      env {
        name  = "DATAFLOW_STAGING_LOCATION"
        value = "gs://${google_storage_bucket.bulk.name}/dataflow/staging"
      }
      env {
        name  = "DATAFLOW_TEMPLATE_GCS_PATH"
        value = var.dataflow_template_gcs_path
      }
      env {
        name  = "DATAFLOW_SERVICE_ACCOUNT_EMAIL"
        value = google_service_account.dataflow.email
      }

      resources {
        limits = {
          cpu    = "2"
          memory = "4Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 3
    }
  }

  depends_on = [
    null_resource.cloud_build_image,
  ]
}

resource "google_cloud_run_v2_service" "call_worker" {
  name     = "${local.name_prefix}-call-worker"
  location = var.region

  template {
    service_account = google_service_account.worker.email

    containers {
      image = local.image_uri

      ports {
        container_port = 8080
      }

      env {
        name  = "BQ_CALL_ATTEMPTS_TABLE"
        value = local.calls_table_id
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }
    }

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }
  }

  depends_on = [
    null_resource.cloud_build_image,
  ]
}

resource "google_cloud_run_service_iam_member" "public_app" {
  location = google_cloud_run_v2_service.app.location
  service  = google_cloud_run_v2_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "google_cloud_run_service_iam_member" "pubsub_worker_invoker" {
  location = google_cloud_run_v2_service.call_worker.location
  service  = google_cloud_run_v2_service.call_worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.pubsub_push.email}"
}

resource "google_pubsub_subscription" "call_worker_push" {
  name  = "${local.name_prefix}-call-worker-push"
  topic = google_pubsub_topic.submissions.id

  ack_deadline_seconds = 60

  push_config {
    push_endpoint = "${google_cloud_run_v2_service.call_worker.uri}/habi/data_crawling/process_call"

    oidc_token {
      service_account_email = google_service_account.pubsub_push.email
    }
  }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"
  }

  depends_on = [
    google_cloud_run_service_iam_member.pubsub_worker_invoker,
  ]
}
