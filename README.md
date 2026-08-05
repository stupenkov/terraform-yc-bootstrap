# terraform-yc-bootstrap

Создаёт landing zone в Yandex Cloud: облако, каталоги `prod` / `stage` / `dev` / `platform`, bucket для Terraform state, service accounts и ключи для env SA.

**Для кого:** DevOps, который разворачивает облако. App-разработчики окружений к bootstrap state bucket не ходят — ключи им отдаёт DevOps.

Секреты **не** лежат отдельным файлом в S3. Они внутри Terraform state в bucket `platform` (и после первого запуска — локально в каталоге `work/`). Lockbox не используется.

---

## 1. Задеплоить облако

**Нужно:** Docker, IAM-токен. Для первого create — права на organization/billing **или** уже существующий `cloud_id`.

### Токен

```bash
yc iam create-token   # после yc init; живёт ~12 ч
```

Подробнее: [IAM-токен](https://yandex.cloud/ru/docs/iam/operations/iam-token/create).

### `.env`

Скопируйте [.env.example](.env.example) и заполните:

```bash
YC_TOKEN=…
BOOTSTRAP_AUTO_APPROVE=1

# Новое облако — оба:
TF_VAR_organization_id=…
TF_VAR_billing_account_id=…

# Или reuse существующего:
# TF_VAR_cloud_id=…
```

### Запуск

```bash
mkdir -p work && docker run --rm --env-file .env \
  -v "$PWD/work:/work" \
  stupean/terraform-yc-bootstrap:latest \
  bootstrap
```

После успеха: folders, state bucket, SA и ключи; state в Object Storage. Секреты и backend-конфиг — в `work/` (без volume запуск ephemeral).

Для воспроизводимого pin берите tag/digest из [GitHub Releases](https://github.com/stupenkov/terraform-yc-bootstrap/releases) вместо `latest`.

---

## 2. Достать секреты

После bootstrap с volume смотрите файлы в `work/` (в clone+Compose — в `terraform/`).

### AWS keys — доступ к state bucket (S3 API)

Нужны Terraform S3 backend и любому, кто читает/пишет bootstrap state.

| Откуда | Что |
|--------|-----|
| **Локально (проще)** | `.backend-credentials` → `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` |
| **Из state в S3** | через Terraform outputs (state уже в bucket): |

```bash
docker run --rm --env-file .env -v "$PWD/work:/work" stupean/terraform-yc-bootstrap:latest \
  output -raw tfstate_access_key

docker run --rm --env-file .env -v "$PWD/work:/work" stupean/terraform-yc-bootstrap:latest \
  output -raw tfstate_secret_key
```

Это static keys SA `tfstate`, не отдельный object в bucket рядом с `workspace.json`.

### Authorized keys — SA каталогов `prod` / `stage` / `dev`

Нужны env Terraform roots и CI от имени `terraform-<env>`.

| Откуда | Что |
|--------|-----|
| **Локально (проще)** | `terraform-<env>-authorized-key.json` (например `terraform-stage-authorized-key.json`) |
| **Из state в S3** | output `terraform_env_sa_key_json` (map по env) |

```bash
# пример для stage
export YC_SERVICE_ACCOUNT_KEY_FILE=work/terraform-stage-authorized-key.json
```

В CI положите содержимое JSON в secret store; app-разработчикам отдайте файл/secret, **не** доступ к bootstrap bucket.

`join` на второй машине выпускает новые AWS keys для state, но **не** пишет заново env SA JSON — их берут из state (`output`) или с машины, где делали первый bootstrap.

---

## 3. Day-two и вторая машина DevOps

Тот же `work/` и `.env`:

```bash
docker run --rm --env-file .env -v "$PWD/work:/work" stupean/terraform-yc-bootstrap:latest plan
# apply | output
```

Только подключиться к уже созданному workspace (peer DevOps):

```bash
docker run --rm --env-file .env -v "$PWD/work:/work" stupean/terraform-yc-bootstrap:latest join
```

Несколько workspace в org — задайте `TFSTATE_BUCKET=…` в `.env`.

---

## Что создаётся

| Ресурс | Назначение |
|--------|------------|
| Cloud (опционально) + billing | Новое облако |
| Folders `prod`, `stage`, `dev`, `platform` | Окружения + shared |
| Bucket в `platform` | Terraform state + `bootstrap/workspace.json` (без секретов) |
| SA `tfstate` + static keys | S3 backend (`AWS_*`) |
| SA `terraform-*` + authorized keys | Provider/CI для env-каталогов |
| SA `bootstrap` | Админ структуры platform/cloud |

---

## Разработка модуля (clone)

```bash
cp .env.example .env
docker compose pull
docker compose run --rm bootstrap
# join |  docker compose run --rm tf plan|apply|output
```

Рабочий каталог Terraform — `terraform/`; секреты: `.backend-credentials`, `terraform-*-authorized-key.json`.

Сборка образа и релизы — [CONTRIBUTING.md](CONTRIBUTING.md).

---

## Notes

- Не коммитьте: `.env`, `.backend-credentials`, `*authorized_key*.json`, `backend.hcl`, `backend.tf`, `.yc-bootstrap-work/`, `*.tfstate*`.
- Не копируйте credentials с чужой машины — у каждого DevOps свои AWS keys (mint на join) или свой volume.
- Если смонтировать корень git-репо как `/work`, артефакты пишутся в `.yc-bootstrap-work/` (gitignored).
- Параллельные `apply` к одному state пока без locking.
