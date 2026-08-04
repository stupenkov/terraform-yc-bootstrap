## Context

См. proposal.md — Why. Образ уже публикуется в `stupean/terraform-yc-bootstrap`; Overview на Hub пустой. Есть `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`, composite publish и CI. GitHub repo = `stupenkov/terraform-yc-bootstrap` ≠ Docker Hub namespace.

## Goals / Non-Goals

**Goals:**
- Автоsync full description из корневого `README.md` + short description.
- Два триггера: изменение README на `main`; после успешного image publish/republish.
- Явный Hub repository name; те же secrets.

**Non-Goals:**
- Отдельный `DOCKERHUB.md` в первой итерации.
- Автосоздание Hub repo (создаётся push’ем образа).
- Синк categories/badges Hub UI.
- Смена текста README под Hub (можно later).

## Decisions

### D1: Action `peter-evans/dockerhub-description@v5`
- Готовый sync README → Hub Overview; Node 24; поддержка short-description и `enable-url-completion`.
- Альтернатива: сырой Hub API curl — больше кода, хуже DX.

### D2: Триггеры (вариант C-lite)
```
dockerhub-description.yml
  on: push@main paths: [README.md, .github/workflows/dockerhub-description.yml]

publish paths (release-please publish job + docker-publish.yml)
  after successful image push → same sync step
```
- README-only правки обновляют Hub без релиза.
- Релиз гарантирует, что после первого успешного publish Overview не пустой.

### D3: Куда класть шаг sync
- Вынести тонкий reusable step/composite **или** дублировать 1 step action в:
  - новый workflow на paths README;
  - `release-please.yml` publish job (после `publish-image`);
  - `docker-publish.yml` (после `publish-image`).
- **Не** обязательно пихать sync внутрь `publish-image` composite: при failure sync удобнее отдельный step; publish-image остаётся про image digests.
- Предпочтение: небольшой local composite `.github/actions/dockerhub-description` **или** прямой `uses: peter-evans/...` в трёх местах — для DRY лучше local composite с inputs username/token.

### D4: Параметры
| Input | Value |
|-------|--------|
| repository | `stupean/terraform-yc-bootstrap` |
| readme-filepath | `./README.md` |
| short-description | `${{ github.event.repository.description }}` с fallback-строкой в workflow, если пусто |
| enable-url-completion | `true` |
| password | `secrets.DOCKERHUB_TOKEN` (нужен scope Read/Write/Delete для description API) |

### D5: Failure isolation
- Sync **после** push; `if: success()` на предыдущем publish step.
- Не `continue-on-error: true` по умолчанию — пустой/устаревший Overview должен быть виден; образ при этом уже на Hub.

## Risks / Trade-offs

- **[Risk] Token scope недостаточен для description** → Mitigation: CONTRIBUTING — Read/Write/Delete; проверить после первого sync.
- **[Risk] GitHub README шумный для Hub** → Mitigation: later `docs/DOCKERHUB.md`; сейчас приемлемо.
- **[Risk] Relative links на Hub** → Mitigation: `enable-url-completion: true`.
- **[Trade-off] Дубли sync на release (README не менялся)** → дёшево; гарантирует актуальность.

## Migration Plan

1. Убедиться, что Hub token с нужным scope.
2. Добавить sync workflow + шаги после publish.
3. Один push README или republish → проверить Overview на Hub.
4. Rollback: удалить workflow/steps; текст на Hub останется последним записанным.

## Open Questions

- Нет блокирующих: fallback short-description текст можно взять из первой строки README при apply, если GitHub description пуст.
