## 1. Compose runtime

- [x] 1.1 Добавить `docker-compose.yml` с сервисом `tf` на образе `stupean/yandex-terraform`, mount `.` → `/app`, working_dir `/app`, проброс `YC_*` и AWS credentials env
- [x] 1.2 Убедиться, что `docker compose run --rm tf version` (или `terraform version`) работает как smoke-check документации
- [x] 1.3 Исправить проброс credentials: пустые `${VAR:-}` в `environment` не затирают `env_file` (`.env`, `.backend-credentials`); проверить day-two с AWS keys только из `.backend-credentials`
- [x] 1.4 Зафиксировать pin образа `stupean/yandex-terraform` (tag или digest) в Compose; упомянуть обновление pin в README

## 2. Backend и credentials

- [x] 2.1 Перевести backend на partial configuration: статика Yandex S3 в репозитории, `bucket`/`key` через `-backend-config`; обновить или заменить `backend.tf.example`
- [x] 2.2 Изменить `local_sensitive_file` credentials на формат `KEY=VALUE` (без bash `export`) при `write_backend_credentials`
- [x] 2.3 Обновить outputs/`backend_config_hint` под partial backend и новый формат credentials-файла

## 3. Bootstrap script

- [x] 3.1 Добавить `scripts/bootstrap.sh` для контейнера: phase1 `init` (local) → `plan` → `apply` (с уважением к `BOOTSTRAP_AUTO_APPROVE`)
- [x] 3.2 Добавить phase2: взять bucket/key и static keys из outputs, `init -migrate-state -force-copy` с `-backend-config`
- [x] 3.3 Сделать повторный запуск идемпотентным: если remote backend уже активен — обычный plan/apply без первичной local→remote миграции
- [x] 3.4 Поддержать resume после сбоя между apply и migrate (local state + bucket уже есть)
- [x] 3.5 Resume: перед migrate всегда проверять незакрытые изменения (plan/apply), не skip’ать apply только из‑за `tfstate_bucket`
- [x] 3.6 Добавить retry/backoff вокруг migrate при кратковременных ошибках доступа к Object Storage
- [x] 3.7 Укрепить детект remote / day-two: при `backend.tf`+`backend.hcl` предпочитать remote init; сервис `tf`/docs — явный `init -backend-config=backend.hcl`

## 4. Документация

- [x] 4.1 Переписать README: Compose-first quick start (`bootstrap`, day-two `plan`/`apply`), prerequisites Docker Compose v2
- [x] 4.2 Кратко описать advanced: ручной migrate, сырой `docker run`, native Terraform
- [x] 4.3 Отметить breaking-change формата `.backend-credentials` (больше не `source`)
- [x] 4.4 Обновить README: поведение `env_file` vs host env, day-two init с `backend.hcl`, pin образа, resume/retry ожидания
