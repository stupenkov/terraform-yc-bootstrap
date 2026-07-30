provider "yandex" {
  # Auth and cloud/folder IDs come from environment:
  # YC_TOKEN or YC_SERVICE_ACCOUNT_KEY_FILE, optional YC_CLOUD_ID / YC_FOLDER_ID
  zone = var.zone
}
