## 1. Shared sync action

- [x] 1.1 Добавить `.github/actions/dockerhub-description/action.yml` (обёртка над `peter-evans/dockerhub-description@v5`)
- [x] 1.2 Зафиксировать `repository: stupean/terraform-yc-bootstrap`, `readme-filepath: ./README.md`, `enable-url-completion: true`
- [x] 1.3 Short description: из GitHub repo description с documented fallback-строкой

## 2. Triggers

- [x] 2.1 Workflow на `push` в `main` с `paths: [README.md, …]` для docs-only sync
- [x] 2.2 Шаг sync после успешного `publish-image` в `release-please.yml`
- [x] 2.3 Шаг sync после успешного `publish-image` в `docker-publish.yml`
- [x] 2.4 Убедиться, что failure sync не откатывает уже запушенный образ (отдельный step после push)

## 3. Docs & secrets

- [x] 3.1 Обновить CONTRIBUTING: sync Overview, явный Hub repo name, scope токена Read/Write/Delete при необходимости
- [x] 3.2 Чеклист проверки: push README или republish → Overview на Hub заполнен
- [x] 3.3 Review fixes: truncate по байтам, guard secrets, concurrency Hub writers, sync в отдельном job
