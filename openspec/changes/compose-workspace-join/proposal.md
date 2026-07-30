## Why

После первого `bootstrap` remote state и локальные `backend.hcl` / `.backend-credentials` остаются только у того, кто запускал. Второй разработчик с одним `.env` (YC credentials) не подключается к уже созданной landing zone и рискует создать дубликаты. Нужен максимально автоматический Compose-путь «присоединиться к существующему workspace» (в идеале только `YC_TOKEN`), без Yandex Lockbox.

## What Changes

- После успешного migrate bootstrap публикует в state bucket несекретный `workspace` meta-object (cloud_id, folder_ids, bucket, state key, tfstate SA id и т.п.).
- **Discovery-first:** join/attach находит workspace через Yandex Cloud API по `YC_TOKEN` (ровно один кандидат → авто; 0/много → явный fallback `TFSTATE_BUCKET` / `TF_VAR_cloud_id`). Имя bucket не обязательный handoff в happy path.
- **Smart `bootstrap`:** на чистой машине с одним `YC_TOKEN` команда `docker compose run --rm bootstrap` сама выбирает create (workspace не найден) vs attach/join (найден ровно один); не создаёт второе облако по ошибке, если workspace уже есть.
- Явный Compose-сервис `join` остаётся как безопасный alias: **только** attach, никогда create.
- AWS keys без Lockbox: новый static access key для SA `tfstate` через YC API под токеном разработчика (локально `.backend-credentials`) или уже заданные `AWS_*` в `.env`.
- README: Dev A = bootstrap (create); Dev B = тот же `bootstrap` (smart attach) или `join`; не копировать файлы с чужой машины.
- **Не** класть secret keys в открытый object в bucket; **не** использовать Yandex Lockbox.

## Capabilities

### New Capabilities
- `workspace-join`: Docker Compose workflow для присоединения к существующему bootstrap workspace (discovery + meta + keys + init), включая smart-режим bootstrap и явный `join`.

### Modified Capabilities
- `tfstate-backend`: после migrate bootstrap SHALL публиковать несекретный workspace meta-object в state bucket; migrate/join не SHALL зависеть от Lockbox.

## Impact

- `scripts/bootstrap.sh` (publish meta; smart create vs attach), `scripts/join.sh` (attach-only), `docker-compose.yml` (сервис `join`).
- README / `.env.example`: happy path Dev B ≈ только `YC_TOKEN`; `TFSTATE_BUCKET` как disambiguation.
- Права IAM: list clouds/folders/buckets + mint static key для SA `tfstate` (или готовые `AWS_*`).
- Облачная структура folders/cloud не меняется; меняется DX multi-dev.
