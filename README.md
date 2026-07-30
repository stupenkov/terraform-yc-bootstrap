# terraform-yc-bootstrap

Создаёт landing zone в Yandex Cloud: облако, каталоги `prod` / `stage` / `dev` / `platform`, bucket для Terraform state и service accounts.

Обычно достаточно один раз пройти **Quick start**.

## Quick start (первый запуск)

**Нужно:** Docker + Compose v2, права на organization/billing (или ID существующего облака), IAM-токен.

```bash
cp .env.example .env
# заполните YC_TOKEN и либо:
#   TF_VAR_organization_id + TF_VAR_billing_account_id  (новое облако)
#   либо TF_VAR_cloud_id                                 (уже есть облако)

docker compose pull
docker compose run --rm bootstrap
```

Один файл `.env`: и вход в Yandex Cloud (`YC_TOKEN`), и параметры Terraform (`TF_VAR_*`). `BOOTSTRAP_AUTO_APPROVE=1` уже в примере — apply пойдёт без лишнего подтверждения; поставьте пусто или `0`, если нужен только plan.

После успеха ресурсы созданы, state в Object Storage. На этом для большинства случаев всё.

Runtime: [stupean/yandex-terraform](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general) (digest в `docker-compose.yml`).

## Если позже нужно что-то поменять

Поправили код или `TF_VAR_*` в `.env` и хотите обновить **уже существующую** landing zone:

```bash
docker compose run --rm bootstrap
# или вручную:
# docker compose run --rm tf init -input=false -backend-config=backend.hcl
# docker compose run --rm tf plan
# docker compose run --rm tf apply
```

Локально уже должны быть `backend.tf`, `backend.hcl`, `.backend-credentials` (их пишет первый bootstrap).

Если ничего менять не планируете — раздел можно не читать.

## Что создаётся

| Ресурс | Назначение |
|--------|------------|
| Cloud (опционально) + billing | Новое облако |
| Folders `prod`, `stage`, `dev`, `platform` | Окружения + shared |
| Bucket в `platform` | Хранение Terraform state |
| SA `bootstrap` / `tfstate` / `terraform-*` | Роли на структуру, state и env-каталоги |

Список ID: `docker compose run --rm tf output`.

## Notes

- Не коммитьте: `.env`, `.backend-credentials`, `backend.hcl`, `backend.tf`, `terraform.tfvars`, `*.tfstate*`.
- Альтернатива `.env` для Terraform-переменных — `terraform.tfvars` (см. `terraform.tfvars.example`); для happy path не нужен.
- Параллельные `apply` к одному state пока без locking — не запускайте одновременно.
