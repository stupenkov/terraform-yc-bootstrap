# terraform-yc-bootstrap

Создаёт landing zone в Yandex Cloud: облако, каталоги `prod` / `stage` / `dev` / `platform`, bucket для Terraform state и service accounts.

## Quick start — без clone (Dev A / Dev B)

**Нужно:** Docker, IAM-токен. Для первого create — права на organization/billing (или `TF_VAR_cloud_id`).

Актуальный **version tag** и **digest** берите из [GitHub Releases](https://github.com/stupenkov/terraform-yc-bootstrap/releases) после первого релиза. До появления Release подставляйте tag/`@sha256:…` из notes вручную — не полагайтесь только на `latest`.

```bash
# env-файл где угодно (можно скопировать из репозитория .env.example)
# YC_TOKEN=...
# Dev A create: TF_VAR_organization_id + TF_VAR_billing_account_id
# или TF_VAR_cloud_id
# Dev B join: достаточно YC_TOKEN

# Pin: VERSION или @sha256:… из GitHub Releases (пример ниже — после первого релиза)
IMAGE=stupean/terraform-yc-bootstrap:VERSION   # например :0.1.0
docker pull "$IMAGE"

# Пустой каталог для локальных артефактов (не корень git-репозитория)
mkdir -p work

docker run --rm --env-file .env \
  -v "$PWD/work:/work" \
  "$IMAGE" \
  bootstrap
```

- `bootstrap` — smart: attach к существующему workspace или create + migrate.
- Только attach: замените команду на `join`.
- `-v …/work:/work` — сохранить `backend.hcl` / `.backend-credentials` / `.terraform` для day-two; без volume — ephemeral.
- Если смонтировать корень этого репозитория как `/work`, entrypoint пишет в `.yc-bootstrap-work/` (gitignored), а не засоряет checkout.

Day-two (тот же volume):

```bash
docker run --rm --env-file .env -v "$PWD/work:/work" \
  "$IMAGE" plan
# … apply | output
```

Образ собирается из этого репозитория (`Dockerfile`). Локально:

```bash
docker build -t stupean/terraform-yc-bootstrap:local .
```

**Pin:** immutable version tag (`:X.Y.Z`) или digest (`@sha256:…` из Release notes). Tag `latest` обновляется при релизе и удобен для экспериментов, но не для воспроизводимого pin. Base runtime внутри — `stupean/yandex-terraform@sha256:e55da7ecc64d3cff1048900f856b84ec6228e2568f1b64f09154500f932bd417`.

Как выходят релизы: Conventional Commits → Release PR (release-please) → merge → в том же workflow tag + Docker Hub. Подробности — в [CONTRIBUTING.md](CONTRIBUTING.md).

Lockbox не используется. Не копируйте `backend.hcl` / `.backend-credentials` с чужой машины.

Если найдено несколько workspace — в env: `TFSTATE_BUCKET=…` (опционально `TF_VAR_cloud_id`).

## Разработка модуля (clone + Compose)

```text
.
├── Dockerfile / docker-compose.yml / .env.example
├── docker/entrypoint.sh
├── terraform/          # root module
├── scripts/            # bootstrap / join
└── examples/           # *.example
```

```bash
cp .env.example .env   # заполнить YC_TOKEN и TF_VAR_*
docker compose pull
docker compose run --rm bootstrap
# attach-only: docker compose run --rm join
# terraform:    docker compose run --rm tf plan|apply|output
```

Terraform working directory — `terraform/`; AWS keys пишутся в `terraform/.backend-credentials`.

## Что создаётся

| Ресурс | Назначение |
|--------|------------|
| Cloud (опционально) + billing | Новое облако |
| Folders `prod`, `stage`, `dev`, `platform` | Окружения + shared |
| Bucket в `platform` | Terraform state + `bootstrap/workspace.json` |
| SA `bootstrap` / `tfstate` / `terraform-*` | Роли на структуру, state и env-каталоги |

## Notes

- Не коммитьте: `.env`, `terraform/.workspace.env`, `terraform/.backend-credentials`, `terraform/backend.hcl`, `terraform/backend.tf`, `.yc-bootstrap-work/`, `*.tfstate*`.
- Provider lock: `terraform/.terraform.lock.hcl` (в корне репо его быть не должно).
- Workspace без `workspace.json`: один раз `bootstrap`/`apply` с машины, где есть state.
- Параллельные `apply` к одному state пока без locking.
