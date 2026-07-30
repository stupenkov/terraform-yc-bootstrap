## 1. Каркас репозитория

- [x] 1.1 Добавить `.gitignore` для Terraform (`.terraform/`, `*.tfstate*`, `.env`, credentials-файлы, crash logs)
- [x] 1.2 Добавить `versions.tf` с Terraform `>= 1.6.3` и `yandex-cloud/yandex` в required_providers
- [x] 1.3 Добавить `providers.tf` с env-based auth (без захардкоженных tokens); variable зоны по умолчанию
- [x] 1.4 Добавить `variables.tf` / `terraform.tfvars.example` для organization_id, billing_account_id, опционального cloud_id, имён каталогов, prefix имени bucket, zone
- [x] 1.5 Задокументировать Docker (`stupean/yandex-terraform`) как основной путь apply; host `.terraformrc` — только как альтернатива для native Terraform по quickstart

## 2. Структура облака

- [x] 2.1 Реализовать create-or-reuse облака (`yandex_resourcemanager_cloud`, если `cloud_id` пуст; иначе использовать переданный ID)
- [x] 2.2 Создать каталоги `prod`, `stage`, `dev` и `platform` (имена из variables) в целевом облаке
- [x] 2.3 Экспортировать cloud_id и folder IDs в outputs

## 3. Bootstrap IAM

- [x] 3.1 Создать bootstrap SA в каталоге `platform` с ролями управления cloud/folder через additive `*_iam_member`
- [x] 3.2 Создать state-access SA в `platform` с `storage.editor` (или эквивалентом) на каталог `platform`
- [x] 3.3 Создать per-environment SA (`terraform-prod|stage|dev`) с `editor` только на свой каталог
- [x] 3.4 Создать static access key для state-access SA; отдать через sensitive outputs (опционально gitignored local file)
- [x] 3.5 Экспортировать все service account IDs в outputs

## 4. Ресурсы Terraform state backend

- [x] 4.1 Создать Object Storage bucket в каталоге `platform` с глобально уникальным именем (prefix + random suffix)
- [x] 4.2 Добавить `backend.tf.example` с настройками Yandex S3 backend (`storage.yandexcloud.net`, skip_* flags, bootstrap state key)
- [x] 4.3 Экспортировать имя bucket, рекомендуемый state key и связанные outputs backend

## 5. Документация и проверка

- [x] 5.1 Написать README: prerequisites, ссылка на Hub `stupean/yandex-terraform`, примеры `docker pull`/`run` для `init`/`plan`/`apply` и migrate-state, auth (`YC_*`), использование outputs, заметка про locking follow-up; кратко — native Terraform fallback
- [x] 5.2 Выполнить `terraform fmt` и `terraform validate` предпочтительно через `stupean/yandex-terraform` (или отметить host-путь с provider mirror)
- [x] 5.3 Убедиться, что secrets не в git; `openspec validate` / checklist по сценариям specs
