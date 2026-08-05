output "cloud_id" {
  description = "Target cloud ID (created or reused)"
  value       = local.cloud_id
}

output "folder_ids" {
  description = "Folder IDs by logical name"
  value = {
    prod     = yandex_resourcemanager_folder.prod.id
    stage    = yandex_resourcemanager_folder.stage.id
    dev      = yandex_resourcemanager_folder.dev.id
    platform = yandex_resourcemanager_folder.platform.id
  }
}

output "service_account_ids" {
  description = "Service account IDs"
  value = {
    bootstrap = yandex_iam_service_account.bootstrap.id
    tfstate   = yandex_iam_service_account.tfstate.id
    terraform = {
      for k, sa in yandex_iam_service_account.terraform_env : k => sa.id
    }
  }
}

output "tfstate_bucket" {
  description = "Object Storage bucket for Terraform remote state"
  value       = yandex_storage_bucket.tfstate.bucket
}

output "bootstrap_state_key" {
  description = "Recommended object key for this bootstrap root state"
  value       = var.bootstrap_state_key
}

output "tfstate_access_key" {
  description = "Static access key ID for the tfstate service account (S3 backend)"
  value       = yandex_iam_service_account_static_access_key.tfstate.access_key
  sensitive   = true
}

output "tfstate_secret_key" {
  description = "Static secret key for the tfstate service account (S3 backend)"
  value       = yandex_iam_service_account_static_access_key.tfstate.secret_key
  sensitive   = true
}

output "terraform_env_sa_key_json" {
  description = "Authorized key JSON per env (prod/stage/dev) for YC_SERVICE_ACCOUNT_KEY_FILE; also stored in Terraform state"
  value       = local.terraform_env_sa_key_json
  sensitive   = true
}

output "backend_config_hint" {
  description = "Hints for configuring the S3 backend after first apply"
  value = {
    endpoint           = "https://storage.yandexcloud.net"
    bucket             = yandex_storage_bucket.tfstate.bucket
    region             = "ru-central1"
    key                = var.bootstrap_state_key
    workspace_meta_key = local.workspace_meta_key
    credentials_file   = var.write_backend_credentials ? var.backend_credentials_path : null
    credentials_format = "env-file KEY=VALUE (Docker --env-file / Compose env_file)"
    backend_file       = "backend.tf (from backend.tf.in)"
    backend_template   = "backend.tf.in"
    backend_config_hcl = "backend.hcl"
    init_migrate       = "terraform init -migrate-state -force-copy -backend-config=backend.hcl"
    join_hint          = "docker compose run --rm join  # peer DevOps / second machine only — not for app env developers"
  }
}

output "env_sa_keys_hint" {
  description = "How to use per-env Terraform SA authorized keys (DevOps handoff to CI / env roots)"
  value = {
    write_local_files = var.write_env_sa_keys
    local_files       = var.write_env_sa_keys ? local.terraform_env_sa_key_filenames : null
    output_name       = "terraform_env_sa_key_json"
    usage_example     = "YC_SERVICE_ACCOUNT_KEY_FILE=terraform-stage-authorized-key.json"
    note              = "Keys live in bootstrap Terraform state (platform bucket). Do not publish as S3 objects. Access to state = access to keys."
  }
}
