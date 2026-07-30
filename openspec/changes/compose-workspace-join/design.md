## Context

См. proposal.md — Why. Уже есть Compose `bootstrap` / `tf`, partial backend, `.env`-first DX, remote state в Object Storage. Constraint: **Yandex Lockbox не используем**. Цель автоматизации: Dev B в happy path вводит только `YC_TOKEN`.

## Goals / Non-Goals

**Goals:**
- Публиковать несекретный workspace meta после migrate.
- Discovery-first attach; `TFSTATE_BUCKET` только для disambiguation.
- Smart `bootstrap`: create vs attach; явный `join` = attach-only.
- Credentials без Lockbox: env AWS_* или mint static key на SA tfstate.

**Non-Goals:**
- Yandex Lockbox / внешние secret managers.
- Хранение AWS secret в открытом object в bucket.
- Автоматический import без remote state.
- CI/CD GitHub Actions в этом change.
- State locking (YDB) — follow-up.

## Decisions

### Workspace meta object in the state bucket
- **Choice:** После успешного migrate записать JSON по ключу `bootstrap/workspace.json` в state bucket. Поля: `schema_version`, `cloud_id`, `folder_ids`, `bucket`, `state_key`, `tfstate_service_account_id`, опционально `platform_folder_id`.
- **Why:** Один store; discovery/join знают куда смотреть; только несекреты.
- **Alternatives:** коммитить `backend.hcl` в git; только out-of-band wiki.

### Discovery-first (not mandatory TFSTATE_BUCKET)
- **Choice:** Primary — через YC API под `YC_TOKEN`: найти cloud(s) → folder `platform` (или id из соглашения) → buckets с prefix вроде `tfstate-` / наличием `bootstrap/workspace.json`. Ровно один → использовать. Ноль или много без явного указателя → ошибка с подсказкой задать `TFSTATE_BUCKET` (и опционально `TF_VAR_cloud_id` для сужения).
- **Why:** Убирает обязательный handoff имени bucket; сохраняет безопасный escape hatch.
- **Alternatives:** только обязательный `TFSTATE_BUCKET` (прежний план, больше ручной работы); угадывание при многих buckets (опасно).

### Smart bootstrap vs explicit join
- **Choice:** `bootstrap` на «чистой» машине (нет remote backend / нет успешного local attach): сначала discovery; attach если один workspace, create если ноль, fail если много. Сервис `join` вызывает тот же attach-path и **никогда** не create.
- **Why:** Dev B может повторить ту же команду `bootstrap`; меньше шансов создать второе облако; `join` для явного «только подключиться».
- **Alternatives:** только отдельный `join` (два mental model); один скрипт без отдельного сервиса.

### Credentials without Lockbox
- **Choice:** (1) `AWS_*` из env если есть. (2) Иначе mint static access key для `tfstate_service_account_id` из meta через YC API/`yc` под `YC_TOKEN`; локальный `.backend-credentials`.
- **Why:** Нет Lockbox; secret не в bucket; у каждого разработчика свой key pair.
- **Alternatives:** шарить один credentials-файл out-of-band (manual fallback).

### Reading meta during discovery
- **Choice:** Предпочтительно читать `bootstrap/workspace.json` через YC Object Storage API / `yc` с IAM token (без AWS keys на этапе discovery). После mint/load AWS keys — обычный S3 Terraform backend init.
- **Why:** Иначе discovery снова требует AWS keys до meta (порочный круг).
- **Alternatives:** сначала mint key «вслепую» без meta (нужен SA id заранее — хуже).

### IAM prerequisites
- **Choice:** Документировать права: list/get на cloud/folder/storage objects + create access key для SA tfstate. Без mint-прав — `AWS_*` в `.env`.
- **Why:** Прозрачный failure mode.

### Publish meta from bootstrap after migrate
- **Choice:** После `run_migrate_init` upload meta текущими AWS keys migrate; идемпотентный overwrite. Для workspace до этой фичи — day-two/bootstrap path или `join --publish`/повторный bootstrap дописывает meta.
- **Why:** Момент, когда bucket точно доступен.

### README
- **Choice:** Dev A: `.env` с token + org/billing → `bootstrap`. Dev B: `.env` с token → `bootstrap` (smart) или `join`. `TFSTATE_BUCKET` — если скрипт попросил disambiguate.
- **Why:** Максимально короткий happy path.

## Risks / Trade-offs

- [Ложное срабатывание discovery → attach не туда] → строгий критерий (наличие meta object); при >1 — fail.
- [Smart bootstrap create при временном сбое list API] → явное логирование; опционально `BOOTSTRAP_FORCE_CREATE=1` только как escape (документировать осторожно) или отказ create без подтверждения — зафиксировать при apply: без force-create в v1, при 0 кандидатов create только если заданы org+billing как сейчас.
- [Нет прав mint / list] → понятная ошибка + fallback AWS_* / TFSTATE_BUCKET.
- [Образ без yc] → raw REST с YC_TOKEN; проверить при apply.
- [Накопление static keys] → док по ротации; follow-up cleanup.

## Migration Plan

1. Publish meta в bootstrap после migrate.
2. Общий attach library/path; `join` + smart ветка в `bootstrap`.
3. Discovery через YC API; `.env.example` + README.
4. Существующие workspace: один раз publish meta.

## Open Questions

- Точные API-вызовы list/get object в образе — spike при `/opsx-apply`.
- Нужен ли `BOOTSTRAP_FORCE_CREATE` в v1 — по умолчанию **нет**; create только при 0 кандидатах и заполненных org/billing (текущий create path).
