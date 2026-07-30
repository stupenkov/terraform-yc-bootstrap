## Why

Happy path всё ещё требует `git clone` репозитория с `.tf`, `docker-compose.yml` и скриптами. Для потребителя landing zone (не контрибьютора) это лишний шаг: нужен только Docker и `YC_TOKEN`. Вариант B — один `docker run` с образом, в котором уже запечены Terraform-модуль и orchestration; clone не обязателен. Плоский корень репозитория мешает и bake-образу, и разделению «модуль / скрипты / упаковка».

## What Changes

- Публикуемый runtime-образ (поверх `stupean/yandex-terraform` или совместимый base), внутри которого лежат Terraform-модуль, `scripts/`, шаблоны backend — версия инфры = тег/digest образа.
- Happy path без clone: `docker run --rm -e YC_TOKEN=... [image] bootstrap|join` (и day-two plan/apply через тот же entrypoint).
- Опциональный bind-mount рабочей директории для кэша локальных артефактов (`backend.hcl`, `.backend-credentials`, `.terraform/`); без mount — ephemeral (каждый раз discovery + mint keys при необходимости).
- **Реорганизация каталогов репозитория:** `terraform/` (root module + `backend.tf.in`), `scripts/`, `docker/` (entrypoint), `examples/` (справочные `*.example`); в корне — `Dockerfile`, `docker-compose.yml`, README, `.env.example`, `.dockerignore`.
- README: первичный путь для Dev A/B — `docker run`; путь с `docker compose` + clone остаётся для разработки модуля и отладки `.tf` (Compose `working_dir` → `terraform/`).
- Сборка/публикация образа (Dockerfile + документированный digests/tags); Lockbox по-прежнему не используется.
- **Не** убираем git-репозиторий как source of truth для разработки — образ собирается из этого репо.

## Capabilities

### New Capabilities
- `bootstrap-image`: all-in-one Docker image с запечённым bootstrap-модулем и командами bootstrap/join/tf без обязательного clone на машине потребителя.

### Modified Capabilities
- `compose-bootstrap`: документированный happy path для потребителей смещается на `docker run` с образом; Compose остаётся поддерживаемым путём для разработчиков репозитория (не удаляется); developer Terraform root = каталог `terraform/`.

## Impact

- Новый `Dockerfile` + `docker/entrypoint.sh`; перенос существующих `.tf` / `backend.tf.in` в `terraform/`, examples в `examples/`; правки путей в Compose и скриптах.
- README / `.env.example`: примеры `docker run -e` / `--env-file`; compose — secondary.
- Сохраняются: discovery/join (`workspace.json`), mint AWS keys без Lockbox, smart bootstrap.
- Затронуты DX, layout репозитория и release-процесс; облачная структура (cloud/folders/bucket/SA) не меняется.
