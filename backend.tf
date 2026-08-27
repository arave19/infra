terraform {
  backend "gcs" {
    bucket = "habi-form-tfstate-aravel-344022-dev"
    prefix = "infra/dev"
  }
}
