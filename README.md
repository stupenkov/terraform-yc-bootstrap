# terraform-yc-bootstrap

Создаёт landing zone в Yandex Cloud: облако, каталоги `prod` / `stage` / `dev` / `platform`, bucket для Terraform state и service accounts.

## Quick start — первый запуск (Dev A)

**Нужно:** Docker + Compose v2, права на organization/billing (или ID существующего облака), IAM-токен.

```bash
cp .env.example .env
# YC_TOKEN=...
# TF_VAR_organization_id + TF_VAR_billing_account_id   (новое облако)
# или TF_VAR_cloud_id                                  (reuse)

docker compose pull
docker compose run --rm bootstrap
```

Один `.env`: вход в YC (`YC_TOKEN`) и параметры Terraform (`TF_VAR_*`).  
`BOOTSTRAP_AUTO_APPROVE=1` в примере — apply без остановки; для только plan уберите/обнулите.

После успеха: ресурсы в облаке, state в Object Storage, в bucket лежит несекретный `bootstrap/workspace.json` (для коллег).

Runtime: [stupean/yandex-terraform](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general) (digest в `docker-compose.yml`).

## Другой разработчик (Dev B)

Не копируйте `backend.hcl` / `.backend-credentials` с чужой машины.

```bash
cp .env.example .env
# достаточно YC_TOKEN=...  (нужен доступ к org/cloud и право создать static key для SA tfstate)

docker compose run --rm bootstrap
# или явно только attach (никогда не создаёт облако):
# docker compose run --rm join
```

Скрипт сам ищет bucket с `bootstrap/workspace.json`, пишет `backend.tf` / `backend.hcl`, выпускает AWS-ключи для SA `tfstate` (или берёт `AWS_*` из `.env`), делает `terraform init`.

Если найдено **несколько** workspace — задайте в `.env`:

```bash
TFSTATE_BUCKET=tfstate-........
```

(опционально сузьте `TF_VAR_cloud_id` / `TF_VAR_organization_id`).

Права: list org/cloud/folder/storage + создание static access key для SA `tfstate`. Без mint-прав положите готовые `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` в `.env`.

Lockbox не используется.

## Если позже нужно что-то поменять

На машине, где уже есть remote backend:

```bash
docker compose run --rm bootstrap
# или:
# docker compose run --rm tf plan
# docker compose run --rm tf apply
```

## Что создаётся

| Ресурс | Назначение |
|--------|------------|
| Cloud (опционально) + billing | Новое облако |
| Folders `prod`, `stage`, `dev`, `platform` | Окружения + shared |
| Bucket в `platform` | Terraform state + `bootstrap/workspace.json` |
| SA `bootstrap` / `tfstate` / `terraform-*` | Роли на структуру, state и env-каталоги |

Outputs: `docker compose run --rm tf output`.

## Notes

- Не коммитьте: `.env`, `.workspace.env`, `.backend-credentials`, `backend.hcl`, `backend.tf`, `terraform.tfvars`, `*.tfstate*`.
- Workspace, созданный до этой фичи: один раз `bootstrap`/`apply` с машины, где есть state — появится `workspace.json`, после этого коллеги смогут `join`.
- Параллельные `apply` к одному state пока без locking.
