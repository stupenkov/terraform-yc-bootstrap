resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "yandex_storage_bucket" "tfstate" {
  folder_id = yandex_resourcemanager_folder.platform.id
  bucket    = "${var.bucket_name_prefix}-${random_id.bucket_suffix.hex}"

  anonymous_access_flags {
    read        = false
    list        = false
    config_read = false
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_member.tfstate_storage_editor,
    yandex_resourcemanager_folder_iam_member.bootstrap_storage_editor,
  ]
}
