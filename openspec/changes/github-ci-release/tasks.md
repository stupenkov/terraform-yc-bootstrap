## 1. CI checks

- [x] 1.1 Добавить `.github/workflows/ci.yml` на `pull_request` и `push` в `main`
- [x] 1.2 Job Terraform: `fmt -check`, `init -backend=false`, `validate` в `terraform/`
- [x] 1.3 Job shellcheck для `scripts/**/*.sh` и `docker/entrypoint.sh`
- [x] 1.4 Job hadolint для корневого Dockerfile
- [x] 1.5 Job `docker build` + smoke (`help` / usage) без login и без push в registry
- [x] 1.6 Убедиться, что workflow не использует Docker Hub / YC secrets

## 2. Release Please

- [x] 2.1 Добавить конфиг release-please (package в корне, type `simple`, стартовая версия `0.1.0`)
- [x] 2.2 Добавить `.github/workflows/release-please.yml` на `push` в `main` с правами на contents/PRs
- [x] 2.3 Проверить, что Release PR создаётся/обновляется без публикации tag до merge

## 3. Docker Hub publish

- [x] 3.1 Publish в `release-please.yml` при `release_created` (не `push: tags` — GITHUB_TOKEN)
- [x] 3.2 Сборка образа и push tags `X.Y.Z` + `latest` в `stupean/terraform-yc-bootstrap`
- [x] 3.3 После push идемпотентно записать image digest в body GitHub Release
- [x] 3.4 Ограничить publish: только `release_created` или manual republish с существующим Release; секреты только `DOCKERHUB_*`

## 5. Follow-up: action versions & DRY publish

- [x] 5.1 Bump actions: checkout@v7, setup-terraform@v4, hadolint@v3.4.0, docker *@v4/@v7, release-please@v5
- [x] 5.2 Composite `.github/actions/publish-image` + `docker/metadata-action` для tags
- [x] 5.3 Подключить composite в `release-please.yml` и `docker-publish.yml`
- [x] 5.4 Review fixes: `update-latest`, guards, CI smoke без buildx, concurrency, normalize v-prefix
- [x] 5.5 Conservative simplify: CI 4→2 jobs; thin composite (без metadata-action); republish retained
