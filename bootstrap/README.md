# Terraform State Bootstrap

Run this once before initializing the main `infra` stack:

```powershell
gcloud config set project aravel-344022
terraform -chdir=infra/bootstrap init
terraform -chdir=infra/bootstrap apply
```

The main stack uses:

```text
gs://habi-form-tfstate-aravel-344022-dev/infra/dev
```
