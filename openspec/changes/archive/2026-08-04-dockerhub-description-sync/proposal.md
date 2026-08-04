## Why

Docker Hub репозиторий `stupean/terraform-yc-bootstrap` публикует образы, но Overview (full description) пустой — потребители на Hub не видят quick start из README. Нужна автоматическая синхронизация описания с git, без ручного копирования в UI Hub.

## What Changes

- Автообновление Docker Hub **full description** из корневого `README.md` репозитория.
- Обновление **short description** (краткая строка Hub) из description GitHub-репозитория или зафиксированной короткой формулировки.
- Триггеры: (1) push в `main` при изменении `README.md`; (2) после успешной публикации образа (release publish / republish), чтобы Overview не отставал от релиза.
- Использование существующих secrets `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN` (при необходимости — расширить scope токена до Read/Write/Delete).
- Документация в CONTRIBUTING: Hub Overview синхронизируется автоматически; явный `repository: stupean/terraform-yc-bootstrap`.
- **Не** вводим отдельный `DOCKERHUB.md`, пока достаточно корневого README (можно добавить later).

## Capabilities

### New Capabilities
- `dockerhub-description`: автоматическая синхронизация short/full description репозитория Docker Hub с документацией в git.

### Modified Capabilities
- `docker-publish`: после успешного push образа система также обновляет описание Hub (чтобы релизный путь гарантированно заполнял Overview).

## Impact

- Новый или расширенный GitHub Actions шаг/workflow; зависимость от `peter-evans/dockerhub-description` (или эквивалент Hub API).
- Те же Docker Hub credentials; возможна смена scope access token.
- CONTRIBUTING / краткая заметка в README опционально.
- Не меняет Terraform-модуль, entrypoint или SemVer-релизный контракт образов.
