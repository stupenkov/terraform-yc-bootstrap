## Why

Репозиторий уже публикует runtime-образ `stupean/terraform-yc-bootstrap` и обещает pin через Releases/digest, но нет GitHub Actions, тегов, CHANGELOG и автопубликации — релиз ручной и легко расходится с документацией. Нужен осознанный цикл: проверки на каждый push/PR, версия и changelog через Release PR, публикация в Docker Hub только после явного merge релиза.

## What Changes

- GitHub Actions workflows для CI-проверок на `pull_request` и `push` в `main` (Terraform fmt/validate, shell/Dockerfile lint, сборка образа со smoke).
- Автоматизация релизов через **release-please**: bot открывает Release PR с SemVer-бамом и CHANGELOG на основе Conventional Commits; merge PR создаёт git tag и GitHub Release.
- После merge Release PR тот же workflow собирает и публикует образ в Docker Hub (`stupean/terraform-yc-bootstrap`) с immutable tag `X.Y.Z` (без префикса `v`) и удобным `:latest`; digest фиксируется в Release notes. (Не через `push: tags` — события от `GITHUB_TOKEN` не стартуют другие workflows.)
- Модель сотрудничества: владельцы могут пушить в `main`; внешние контрибьюторы — только fork + PR; секреты Docker Hub недоступны workflow из fork.
- Документация: CONTRIBUTING (кратко), обновление README под pin из Releases; описание secrets/branch rules для мейнтейнера.
- **Не** публикуем образ на каждый push в `main` и **не** гоняем e2e `terraform apply` в YC в CI.

## Capabilities

### New Capabilities
- `ci-checks`: обязательные проверки качества на PR и push в `main` без облачных credentials и без push в registry.
- `release-automation`: осознанный Release PR (release-please), SemVer, CHANGELOG, git tag и GitHub Release.
- `docker-publish`: публикация bootstrap-образа в Docker Hub только по релизному тегу.

### Modified Capabilities
- `bootstrap-image`: требования к версионированию/pin уточняются под автоматизированный релиз (tag/digest из GitHub Release, а не ручной процесс).

## Impact

- Новые файлы: `.github/workflows/*`, конфиг release-please, `CHANGELOG.md` (ведение ботом), краткий `CONTRIBUTING.md`, правки README.
- Secrets репозитория: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN` (или эквивалент); права GitHub Actions / bot для создания PR и тегов.
- Branch protection / restrict push: документированные рекомендации (owner + release bot на `main`).
- Образ `stupean/terraform-yc-bootstrap` и base `stupean/yandex-terraform` (digest) не меняют облачную логику Terraform; меняется только release/DX контур.
