# terraform-yc-bootstrap

Bootstrap landing zone в Yandex Cloud: облако (create или reuse), каталоги `prod` / `stage` / `dev` / `platform`, Object Storage для Terraform remote state и service accounts с нужными ролями.

## Prerequisites

- Docker
- Organization в Yandex Cloud и активный billing account
- Credentials с правом создать облако (`resource-manager.clouds.creator` / права владельца) **или** ID уже существующего облака
- IAM-токен (`YC_TOKEN`) или файл authorized key сервисного аккаунта (`YC_SERVICE_ACCOUNT_KEY_FILE`)

Предпочтительный runtime: образ [stupean/yandex-terraform](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general) (Terraform + mirror провайдера Yandex Cloud). Устанавливать Terraform на хост не обязательно.

## Быстрый старт (Docker)

```bash
docker pull stupean/yandex-terraform

cp terraform.tfvars.example terraform.tfvars
# заполните organization_id / billing_account_id (создание облака)
# или cloud_id (reuse существующего)

export YC_TOKEN=$(yc iam create-token)   # или используйте SA key
# export YC_SERVICE_ACCOUNT_KEY_FILE=/keys/sa-key.json

docker run --rm -it \
  -e YC_TOKEN="$YC_TOKEN" \
  -v "$(pwd)":/app \
  stupean/yandex-terraform init

docker run --rm -it \
  -e YC_TOKEN="$YC_TOKEN" \
  -v "$(pwd)":/app \
  stupean/yandex-terraform plan

docker run --rm -it \
  -e YC_TOKEN="$YC_TOKEN" \
  -v "$(pwd)":/app \
  stupean/yandex-terraform apply
```

При работе через SA key смонтируйте JSON внутрь контейнера и передайте путь **внутри** контейнера:

```bash
docker run --rm -it \
  -e YC_SERVICE_ACCOUNT_KEY_FILE=/keys/sa-key.json \
  -v "$(pwd)":/app \
  -v /path/to/sa-key.json:/keys/sa-key.json:ro \
  stupean/yandex-terraform plan
```

Первый `apply` пишет **local state** (файлы `*.tfstate`* в `.gitignore`). Сразу после успешного apply мигрируйте state в bucket (см. ниже).

## Миграция state в Object Storage

После первого apply:

1. Скопируйте `backend.tf.example` → `backend.tf` и подставьте имя bucket из output `tfstate_bucket`.
2. Загрузите static keys (если включён `write_backend_credentials`):

```bash
source .backend-credentials
```

1. Переинициализируйте backend:

```bash
docker run --rm -it \
  -e YC_TOKEN="$YC_TOKEN" \
  -e AWS_ACCESS_KEY_ID \
  -e AWS_SECRET_ACCESS_KEY \
  -v "$(pwd)":/app \
  stupean/yandex-terraform init -migrate-state
```

Endpoint backend: `https://storage.yandexcloud.net`. Нужные `skip_*` flags уже в `backend.tf.example`.

Рекомендуемый object key для этого root: `bootstrap/terraform.tfstate` (variable `bootstrap_state_key`). Для будущих env-roots удобна convention вида `prod/terraform.tfstate`, `stage/...` в том же bucket.

## Что создаётся


| Ресурс                                     | Назначение                                                                                |
| ------------------------------------------ | ----------------------------------------------------------------------------------------- |
| Cloud (опционально) + billing binding      | Новое облако в organization                                                               |
| Folders `prod`, `stage`, `dev`, `platform` | Окружения + shared platform                                                               |
| Bucket в `platform`                        | Remote Terraform state                                                                    |
| SA `bootstrap`                             | Управление структурой (`resource-manager.admin` на cloud, `storage.editor` на `platform`) |
| SA `tfstate` + static access key           | Доступ к state bucket (`storage.editor` на `platform`)                                    |
| SA `terraform-prod|stage|dev`              | `editor` только на свой каталог                                                           |


Полезные outputs: `cloud_id`, `folder_ids`, `service_account_ids`, `tfstate_bucket`, `bootstrap_state_key`, `backend_config_hint`, sensitive `tfstate_access_key` / `tfstate_secret_key`.

## Auth и переменные


| Variable / env                | Описание                                            |
| ----------------------------- | --------------------------------------------------- |
| `YC_TOKEN`                    | IAM token (~12 часов)                               |
| `YC_SERVICE_ACCOUNT_KEY_FILE` | Путь к SA authorized key JSON                       |
| `organization_id`             | Нужен при создании облака                           |
| `billing_account_id`          | Нужен при создании облака                           |
| `cloud_id`                    | Пусто = создать; иначе reuse                        |
| `folder_names`                | Имена каталогов (defaults: prod/stage/dev/platform) |
| `bucket_name_prefix`          | Prefix имени bucket (+ random suffix)               |


Секреты не коммитьте: `terraform.tfvars`, `.env`, `.backend-credentials`, `*.tfstate*` в `.gitignore`.

## State locking (follow-up)

Сейчас locking не включён. Параллельные `apply` к одному state опасны — работайте по одному оператору. Позже можно добавить YDB (DynamoDB-compatible) по [документации Yandex Cloud](https://yandex.cloud/en/docs/tutorials/infrastructure-management/terraform-state-lock).

## Native Terraform (альтернатива)

Если без Docker: установите Terraform `>= 1.6.3` и настройте mirror провайдера в `~/.terraformrc` по [quickstart](https://yandex.cloud/ru/docs/terraform/quickstart):

```hcl
provider_installation {
  network_mirror {
    url     = "https://terraform-mirror.yandexcloud.net/"
    include = ["registry.terraform.io/*/*"]
  }
  direct {
    exclude = ["registry.terraform.io/*/*"]
  }
}
```

Дальше те же `init` / `plan` / `apply` / `init -migrate-state` на хосте.