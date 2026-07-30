## Why

Текущий README требует много ручных шагов на хосте (`docker run` копипаста, `cp backend.tf.example`, подстановка bucket, `source` credentials, `init -migrate-state`). Это хрупко и плохо работает на Windows/macOS/Linux без bash. Нужен единый кроссплатформенный happy path через Docker Compose, где оркестрация local apply → remote migrate выполняется внутри контейнера. После первой реализации code review выявил баги DX/надёжности (Compose затирает `env_file`, хрупкий day-two/resume) — их нужно закрыть в том же change.

## What Changes

- Добавить `docker-compose.yml` с сервисом на образе `stupean/yandex-terraform` (volume репозитория, проброс `YC_*` / AWS credentials).
- Добавить контейнерный скрипт bootstrap: `init` → `apply` → migrate state в Object Storage (`-migrate-state -force-copy`) без ручного копирования backend-файлов на хосте.
- Перевести S3 backend на partial configuration (`bucket`/`key` через `-backend-config`), чтобы не править `backend.tf` руками.
- Сделать credentials для migrate читаемыми внутри контейнера (outputs / env-file формат `KEY=VALUE`), без зависимости от bash `source` на хосте.
- Сократить README до Compose-first сценария; native Terraform и сырой `docker run` — опциональные advanced-пути.
- Обновить требование миграции state: оператором может быть автоматизированный Compose entrypoint, а не только ручные шаги.
- Исправить проброс credentials в Compose: пустые `${VAR:-}` в `environment` не должны затирать значения из `env_file` (особенно `AWS_*` из `.backend-credentials`).
- Day-two через сервис `tf`: гарантировать рабочий `init` с `-backend-config=backend.hcl` и AWS keys, а не только «если остался `.terraform/`».
- Ужесточить bootstrap resume: не мигрировать при незавершённом apply; retry migrate при IAM/propagation delay.
- Зафиксировать pin образа `stupean/yandex-terraform` (tag или digest).

## Capabilities

### New Capabilities
- `compose-bootstrap`: кроссплатформенный Docker Compose workflow для запуска Terraform и one-shot bootstrap (local apply + remote migrate) без хостового bash.

### Modified Capabilities
- `tfstate-backend`: миграция local → remote SHALL поддерживаться автоматизированным Compose/bootstrap entrypoint (partial backend config, non-interactive migrate); формат локальных credentials не должен требовать bash `export`/`source` на хосте; resume/migrate SHALL быть устойчивы к незавершённому apply и кратковременным ошибкам доступа к bucket.

## Impact

- Файлы: `docker-compose.yml`, `scripts/bootstrap.sh`, `backend.tf.in` / partial backend layout, правки формата `.backend-credentials`, README.
- Документация: README под Compose как основной путь; day-two init с `backend.hcl` задокументирован и/или автоматизирован.
- Зависимости оператора: Docker Engine + Compose v2; Terraform на хосте не обязателен.
- Образ `stupean/yandex-terraform` остаётся runtime (с pin tag/digest); логика bootstrap живёт в репозитории, не в образе.
- Облачные Terraform resources (cloud/folders/IAM/bucket) по сути не меняются; меняется DX, надёжность Compose/bootstrap и способ включения remote backend.
