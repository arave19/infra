# Habi Form Infrastructure

Terraform stack for dev infrastructure on GCP project `aravel-344022`.

Region:

```text
us-central1
```

Resources:

- Artifact Registry Docker repository: `habi`
- Cloud Storage bucket for form evidence images
- Cloud Storage bucket for bulk files and Dataflow staging/temp
- BigQuery dataset and tables:
  - `form_submissions`
  - `call_attempts`
  - `bulk_uploads`
- Pub/Sub topic and push subscription
- Dataflow API, service account and IAM for bulk processing
- Cloud Run app service
- Cloud Run fake call worker service
- Service accounts and IAM bindings
- Optional Cloud Build execution through Terraform

## Required Permissions

The authenticated account must be able to:

- Enable/list project services: `serviceusage.services.use`
- Create buckets: `storage.buckets.create`
- Create Artifact Registry repositories
- Create Cloud Run services
- Create Pub/Sub topics/subscriptions
- Create BigQuery datasets/tables
- Create Dataflow jobs
- Create service accounts and IAM bindings

The current local account failed on:

```text
serviceusage.services.use
storage.buckets.create
```

## Bootstrap Terraform State

Run once:

```powershell
gcloud config set project aravel-344022
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply
```

If APIs are already enabled but Service Usage permissions are restricted:

```powershell
terraform -chdir=infra/bootstrap apply -var enable_project_services=false
```

State bucket:

```text
gs://habi-form-tfstate-aravel-344022-dev
```

## Main Stack

After the state bucket exists:

```powershell
terraform -chdir=infra init
terraform -chdir=infra plan
```

To let Terraform run Cloud Build before deploying Cloud Run:

```powershell
terraform -chdir=infra apply -var run_cloud_build=true
```

To deploy with a specific image tag:

```powershell
terraform -chdir=infra apply -var run_cloud_build=true -var image_tag=dev-bulk-v1
```

To enable real Dataflow launch from Cloud Run:

```powershell
terraform -chdir=infra apply -var run_cloud_build=true -var image_tag=dev-bulk-v1 -var enable_dataflow_runner=true -var dataflow_template_gcs_path=gs://habi-form-aravel-344022-dev-bulk/dataflow/templates/habi-bulk-phone.json
```

If the image is already built and pushed:

```powershell
terraform -chdir=infra apply -var run_cloud_build=false
```

## Tests

```powershell
pytest -q
terraform fmt -recursive
terraform validate
```

## Diagram

Editable draw.io architecture:

```text
docs/habi-form-architecture.drawio
```
