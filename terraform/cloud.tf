locals {
  create_cloud = var.cloud_id == ""
  cloud_id     = local.create_cloud ? yandex_resourcemanager_cloud.this[0].id : var.cloud_id
}

resource "yandex_resourcemanager_cloud" "this" {
  count = local.create_cloud ? 1 : 0

  name            = var.cloud_name
  organization_id = var.organization_id

  lifecycle {
    precondition {
      condition     = var.organization_id != ""
      error_message = "organization_id is required when cloud_id is empty (creating a new cloud)."
    }
    precondition {
      condition     = var.billing_account_id != ""
      error_message = "billing_account_id is required when cloud_id is empty (creating a new cloud)."
    }
  }
}

resource "yandex_billing_cloud_binding" "this" {
  count = local.create_cloud ? 1 : 0

  billing_account_id = var.billing_account_id
  cloud_id           = yandex_resourcemanager_cloud.this[0].id
}
