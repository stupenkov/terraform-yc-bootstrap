variable "organization_id" {
  description = "Yandex Cloud organization ID (required when creating a new cloud)"
  type        = string
  default     = ""
}

variable "billing_account_id" {
  description = "Billing account ID to bind when creating a new cloud"
  type        = string
  default     = ""
}

variable "cloud_id" {
  description = "Existing cloud ID to reuse. Leave empty to create a new cloud."
  type        = string
  default     = ""
}

variable "cloud_name" {
  description = "Name for a newly created cloud"
  type        = string
  default     = "main"
}

variable "zone" {
  description = "Default availability zone for the Yandex provider"
  type        = string
  default     = "ru-central1-d"
}

variable "folder_names" {
  description = "Display names for environment and platform folders"
  type = object({
    prod     = string
    stage    = string
    dev      = string
    platform = string
  })
  default = {
    prod     = "prod"
    stage    = "stage"
    dev      = "dev"
    platform = "platform"
  }
}

variable "bucket_name_prefix" {
  description = "Prefix for the Terraform state Object Storage bucket (suffix is random)"
  type        = string
  default     = "tfstate"
}

variable "bootstrap_state_key" {
  description = "Object key for this bootstrap root's remote state"
  type        = string
  default     = "bootstrap/terraform.tfstate"
}

variable "write_backend_credentials" {
  description = "If true, write AWS-compatible backend credentials to a local gitignored file"
  type        = bool
  default     = true
}

variable "backend_credentials_path" {
  description = "Path for optional local backend credentials file"
  type        = string
  default     = ".backend-credentials"
}

variable "write_env_sa_keys" {
  description = "If true, write per-env Terraform SA authorized key JSON files locally (gitignored; for YC_SERVICE_ACCOUNT_KEY_FILE)"
  type        = bool
  default     = true
}
