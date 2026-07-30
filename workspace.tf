locals {
  workspace_meta_key = "bootstrap/workspace.json"
  workspace_meta = {
    schema_version             = 1
    cloud_id                   = local.cloud_id
    bucket                     = yandex_storage_bucket.tfstate.bucket
    state_key                  = var.bootstrap_state_key
    tfstate_service_account_id = yandex_iam_service_account.tfstate.id
    platform_folder_id         = yandex_resourcemanager_folder.platform.id
    folder_ids = {
      prod     = yandex_resourcemanager_folder.prod.id
      stage    = yandex_resourcemanager_folder.stage.id
      dev      = yandex_resourcemanager_folder.dev.id
      platform = yandex_resourcemanager_folder.platform.id
    }
  }
}

# Non-secret workspace pointer for other developers (discovery / join). No AWS secrets here.
resource "yandex_storage_object" "workspace_meta" {
  bucket  = yandex_storage_bucket.tfstate.bucket
  key     = local.workspace_meta_key
  content = jsonencode(local.workspace_meta)

  access_key = yandex_iam_service_account_static_access_key.tfstate.access_key
  secret_key = yandex_iam_service_account_static_access_key.tfstate.secret_key
}
