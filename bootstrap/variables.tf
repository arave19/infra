variable "project_id" {
  type    = string
  default = "aravel-344022"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "state_bucket_name" {
  type    = string
  default = "habi-form-tfstate-aravel-344022-dev"
}

variable "enable_project_services" {
  type    = bool
  default = true
}
