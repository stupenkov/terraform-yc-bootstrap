## Context

См. proposal.md — Why. Сейчас: Conventional Commits и Dockerfile есть, `.github/workflows` нет, тегов/CHANGELOG/автопубликации нет. Образ потребителя — `stupean/terraform-yc-bootstrap`; GitHub — `stupenkov/terraform-yc-bootstrap`. Модель работы: владельцы пушат в `main`, внешние — fork + PR. Выбран осознанный Release PR, а не auto-release на каждый `feat`.

## Goals / Non-Goals

**Goals:**
- Три связанных контура: CI checks, release-please (Release PR), publish в Docker Hub по tag.
- Один SemVer на модуль+образ; digest в Release notes.
- Безопасность fork PR: без publish secrets.

**Non-Goals:**
- e2e bootstrap/apply в YC в CI.
- Multi-arch (arm64) в первой итерации.
- Cosign/SBOM/attestations (можно phase 2).
- Обязательный PR для владельца на каждый коммит.
- Смена имени Docker Hub image или base runtime `stupean/yandex-terraform`.

## Decisions

### D1: release-please вместо semantic-release
- **Выбор:** [googleapis/release-please](https://github.com/googleapis/release-please) (GitHub Action) с манифестом/конфигом для одного пакета в корне (release type: `simple` или `terraform-module` — достаточно `simple` + Conventional Commits).
- **Почему:** явно соответствует «осознанный Release PR»; changelog и bump видны до публикации; меньше сюрпризов при прямых push владельца в `main`.
- **Альтернативы:** semantic-release (сразу tag на merge `feat`) — отвергнут пользователем; ручные tags — хрупко для CHANGELOG.

### D2: Разделение workflows
```
ci.yml              → 2 jobs: lint (tf+shell+hadolint) | image smoke
release-please.yml  → Release PR; on release_created → composite publish
docker-publish.yml  → workflow_dispatch republish (update-latest default false)
.publish-image      → login + buildx + push + digest in notes (без metadata-action)
```
- Publish в том же workflow, что release-please (`GITHUB_TOKEN` не триггерит tag workflows).
- Теги: явный `X.Y.Z` (+ `latest` если `update-latest`); CI smoke без buildx.
- `concurrency` на release-please (`cancel-in-progress: false`).

### D3: Версионные Docker tags
- Git tag: `v1.2.3` (как у release-please по умолчанию).
- Docker tags: `1.2.3` (без `v`); `latest` на обычном релизе; на republish — только если `update_latest`.
- В README/examples: `stupean/terraform-yc-bootstrap:1.2.3` или `@sha256:…`.
- **Альтернатива:** Docker tag с `v` префиксом — хуже DX у docker pull; единообразие с git tag ценой привычки.

### D4: Состав CI checks
| Job | Инструмент | Заметки |
|-----|------------|---------|
| lint | terraform fmt/validate, shellcheck, hadolint | один job, один checkout |
| image | `docker build` + `docker run … help` | без buildx/login/push |

Опционально later: tflint, actionlint, trivy — не блокируют v1.

### D5: Секреты и права
- Repo secrets: `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`.
- `pull_request` из fork: только checks; `secrets` publish не использовать (`pull_request_target` для publish — **запрещён** в этом design).
- Permissions: release-please — `contents: write`, `pull-requests: write`; publish — `contents: write` (обновить release body digest) + docker login.
- Рекомендация мейнтейнеру (документировать, не обязательно автоматизировать): restrict who can push to `main` = owner + github-actions; для внешних — только PR.

### D6: CONTRIBUTING + README
- Короткий CONTRIBUTING: Conventional Commits, fork+PR для внешних, владельцы → `main`, релиз = merge Release PR.
- README: убрать ощущение, что `:latest` — единственный pin; ссылка на Releases; пример с version tag.

### D7: Bootstrapping первого релиза
- Стартовая версия: `0.1.0` (или `1.0.0`, если считать текущий образ production-ready — **выбрать `0.1.0`**, пока публичный контракт образа молодой).
- Первый Release PR создаётся release-please после появления конфигурации и коммитов с последнего tag (тегов ещё нет → весь history или `bootstrap-sha` в конфиге).

## Risks / Trade-offs

- **[Risk] Прямой push владельца ломает main до падения CI** → Mitigation: те же checks на push; publish только при `release_created` после Release PR; при желании позже включить required checks + bypass только для admin.
- **[Risk] release-please не открывает PR из‑за типов коммитов** → Mitigation: документировать Conventional Commits; в design/CONTRIBUTING примеры `feat`/`fix`/`!`.
- **[Risk] Расхождение git `v1.2.3` и Docker `1.2.3`** → Mitigation: явно описать в README; в Release notes оба идентификатора + digest.
- **[Risk] Docker Hub rate/auth failures** → Mitigation: отдельный job с явным fail; не смешивать с CI checks PR.
- **[Risk] GITHUB_TOKEN не триггерит другие workflows** → Mitigation: publish в `release-please.yml` по `release_created`; ручной republish через `docker-publish.yml`.
- **[Trade-off] Нет e2e YC** → быстрее и безопаснее CI; регрессии apply ловятся вручную/позже.
- **[Trade-off] Только amd64** → упрощение; Apple Silicon через emulation/позже multi-arch.

## Migration Plan

1. Добавить workflows + release-please config + docs (без секретов publish checks всё равно зелёные).
2. Задать repo secrets Docker Hub.
3. Настроить restrict push / branch rules вручную по CONTRIBUTING/README note.
4. Дождаться первого Release PR → merge → убедиться tag + image + digest.
5. Обновить README pin на первый реальный version tag.
6. Rollback: отключить/удалить workflows; теги и образы в Hub остаются (не удалять автоматически).

## Open Questions

- Точный package release-please type (`simple` vs иное) — уточняется при apply по актуальной документации action; на requirements не влияет.
- Нужен ли сразу tflint — отложено; можно добавить отдельным chore без смены specs.
