resource "yandex_resourcemanager_folder" "prod" {
  cloud_id    = local.cloud_id
  name        = var.folder_names.prod
  description = "Production environment"

  depends_on = [yandex_billing_cloud_binding.this]
}

resource "yandex_resourcemanager_folder" "stage" {
  cloud_id    = local.cloud_id
  name        = var.folder_names.stage
  description = "Staging environment"

  depends_on = [yandex_billing_cloud_binding.this]
}

resource "yandex_resourcemanager_folder" "dev" {
  cloud_id    = local.cloud_id
  name        = var.folder_names.dev
  description = "Development environment"

  depends_on = [yandex_billing_cloud_binding.this]
}

resource "yandex_resourcemanager_folder" "platform" {
  cloud_id    = local.cloud_id
  name        = var.folder_names.platform
  description = "Shared platform resources (Terraform state, bootstrap IAM, future shared infra)"

  depends_on = [yandex_billing_cloud_binding.this]
}

locals {
  env_folders = {
    prod  = yandex_resourcemanager_folder.prod
    stage = yandex_resourcemanager_folder.stage
    dev   = yandex_resourcemanager_folder.dev
  }
}
