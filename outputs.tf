output "app_url" {
  value = google_cloud_run_v2_service.app.uri
}

output "call_worker_url" {
  value = google_cloud_run_v2_service.call_worker.uri
}

output "image_bucket" {
  value = google_storage_bucket.images.name
}

output "bulk_bucket" {
  value = google_storage_bucket.bulk.name
}

output "dataflow_service_account" {
  value = google_service_account.dataflow.email
}

output "artifact_repository" {
  value = google_artifact_registry_repository.docker.name
}

output "pubsub_topic" {
  value = google_pubsub_topic.submissions.id
}

output "bigquery_dataset" {
  value = google_bigquery_dataset.habi.dataset_id
}
