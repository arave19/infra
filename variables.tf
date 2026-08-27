variable "project_id" {
  type    = string
  default = "aravel-344022"
}

variable "region" {
  type    = string
  default = "us-central1"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "resource_prefix" {
  type    = string
  default = "habi-form"
}

variable "artifact_repository_id" {
  type    = string
  default = "habi"
}

variable "image_name" {
  type    = string
  default = "habi-form-app"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "run_cloud_build" {
  type    = bool
  default = false
}

variable "enable_project_services" {
  type    = bool
  default = true
}

variable "enable_dataflow_runner" {
  type    = bool
  default = false
}

variable "dataflow_template_gcs_path" {
  type    = string
  default = ""
}
