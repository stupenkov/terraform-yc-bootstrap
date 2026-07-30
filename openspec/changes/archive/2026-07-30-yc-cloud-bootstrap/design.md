## Context

Greenfield-репозиторий `terraform-yc-bootstrap`. Мотивация: см. proposal.md — Why. Требования: specs `cloud-structure`, `tfstate-backend`, `bootstrap-iam`.

Предпосылки оператора (вне Terraform): organization в Yandex Cloud, активный billing account и credentials с правом создать облако (уровень organization) или управлять существующим. Предпочтительный runtime: Docker-образ [`stupean/yandex-terraform`](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general). Auth — по [quickstart Yandex Cloud Terraform](https://yandex.cloud/ru/docs/terraform/quickstart) / контракту env-переменных provider (`YC_TOKEN` или `YC_SERVICE_ACCOUNT_KEY_FILE`). Remote state — по [Object Storage Terraform state](https://yandex.cloud/en/docs/terraform/tutorials/terraform-state-storage).

## Goals / Non-Goals

**Goals:**
- Один Terraform root, который создаёт структуру облака, state bucket и SA за один apply-путь.
- Явный двухфазный flow state: local apply → создать bucket → migrate в S3 backend.
- Разумные IAM-defaults с variables для имён и опцией create-vs-reuse облака.
- Outputs, пригодные для будущих roots окружений (folder IDs, bucket, SA IDs, backend snippet).
- Удобный воспроизводимый apply без установки Terraform и Yandex provider mirror на хост (путь через Docker).

**Non-Goals:**
- YDB DynamoDB-compatible state locking (задокументировать как optional follow-up).
- Workload-ресурсы (VPC, compute, k8s) внутри каталогов окружений.
- Multi-cloud или настройка organization federation.
- Автоматическое создание billing account.
- Сборка и сопровождение образа `stupean/yandex-terraform` в этом репозитории.

## Decisions

### 1. Плоский root module (пока без multi-stack)
- **Choice:** Один root в корне репозитория (например, `*.tf` + `README.md`), `modules/` — только если появится повторение (folders/SAs).
- **Why:** Bootstrap небольшой; разбиение на stacks усложняет миграцию state до появления bucket.
- **Alternatives:** layout `0-bootstrap` / landing-zone с несколькими каталогами (отложить, пока окружениям не понадобятся отдельные states).

### 2. Создание облака vs reuse
- **Choice:** Variable `cloud_id` опциональна. Пусто → `yandex_resourcemanager_cloud`; задана → data source / использовать как есть. При создании всегда нужны `organization_id` и `billing_account_id`.
- **Why:** Подходит и greenfield, и brownfield.
- **Alternatives:** Всегда создавать (ломает brownfield); всегда reuse (не закрывает «создать облако»).

### 3. Набор каталогов
- **Choice:** Четыре каталога: `prod`, `stage`, `dev`, `platform` (имена переопределяемые).
- **Why:** Изоляция окружений плюс общий platform-каталог для state bucket, bootstrap SA и будущих общих ресурсов (не только Terraform state).
- **Alternatives:** Узкое имя `tfstate` (слишком специфично); bucket в `dev` (смешивает env и shared); отдельное облако под bootstrap (тяжелее).

### 4. Именование и размещение bucket
- **Choice:** Bucket в каталоге `platform`; имя из variable с uniqueness-суффиксом (например, `random_id` или фрагмент `cloud_id`) — имена Object Storage глобально уникальны. В имени bucket можно оставить `tfstate` как намёк на назначение.
- **Why:** Избежать коллизий; держать state (и позже shared) вне workload-каталогов.
- **Alternatives:** Только фиксированное имя (хрупко); bucket на каждое env (вне scope «минимум одно хранилище state» — можно добавить позже).

### 5. Chicken-and-egg remote state
- **Choice:** Поставлять backend block закомментированным или в `backend.tf.example`. Первый apply: local state. После apply: включить backend, `terraform init -migrate-state`. Задокументировать AWS-compatible env (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) из static keys state SA.
- **Why:** Bucket не может хранить state до своего создания; совпадает с практикой YC docs и landing-zone.
- **Alternatives:** Сначала bucket через CLI (лишний imperative шаг); два Terraform roots (больше церемонии).

### 6. Модель IAM
- **Choice:**
  - SA `bootstrap` в `platform`: роли на управление каталогами в облаке (`resource-manager.admin` или более узкие + необходимые) и storage в `platform`.
  - SA `tfstate` в `platform`: `storage.editor` на каталог `platform` + static access key для S3 backend (имя SA остаётся purpose-specific).
  - SA `terraform-prod|stage|dev` в каждом env-каталоге: `editor` только на свой каталог.
  - Использовать `*_iam_member` (additive), никогда `*_iam_policy`.
- **Why:** Least privilege для env SA; общий state SA для backends; bootstrap SA для дальнейших изменений структуры. Согласуется с tutorial YC про SA + static key для state.
- **Alternatives:** Один SA с cloud `admin` (проще, слабее изоляция); только authorized keys без static keys (S3 backend всё равно нуждается в static keys).

### 7. Provider и версии
- **Choice:** provider `yandex-cloud/yandex`; Terraform `>= 1.6.3` (нужны skip flags S3 backend).
- **Why:** Совместимость с актуальными опциями Object Storage backend.

### 8. Секреты
- **Choice:** Помечать secret static key как sensitive output; опционально `local_file` в `.env` / `.backend-credentials`, перечисленные в `.gitignore`. Никогда не коммитить ключи.
- **Why:** Оператору нужны ключи для backend; git должен оставаться чистым.

### 9. Предпочтительный runtime apply: Docker-образ
- **Choice:** Документировать [`stupean/yandex-terraform`](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general) как основной способ запускать `init` / `plan` / `apply` / migrate-state. Mount репозитория в `/app`; передавать `YC_TOKEN` или `YC_SERVICE_ACCOUNT_KEY_FILE` (+ env cloud/folder по необходимости). В образе уже есть Yandex provider mirror, поэтому host `.terraformrc` на Docker-пути не нужен. Нативный Terraform на хосте — документированная альтернатива (тогда нужен host mirror по quickstart).
- **Why:** Совпадает с существующим thin YC Terraform runtime; снижает friction настройки; credentials остаются env-based.
- **Alternatives:** Только host Terraform (больше setup); свой project-specific образ (лишнее дублирование).

## Risks / Trade-offs

- [Нет прав на уровне organization] → Задокументировать нужные роли (`resource-manager.clouds.creator` / cloud owner); поддержать путь reuse через `cloud_id`.
- [Глобальная коллизия имени bucket] → Random suffix; понятная ошибка при конфликте.
- [Потеря local state до migrate] → README подчёркивает немедленную миграцию; `.gitignore` держит `*.tfstate*` только локально.
- [Слишком широкие права bootstrap SA] → Предпочитать folder-scoped роли, где API позволяет; задокументировать, если для создания каталогов неизбежна cloud-level роль.
- [Нет state locking] → Параллельные apply могут повредить state; задокументировать YDB lock как follow-up; рекомендовать одного оператора до этого.
- [IAM eventual consistency] → Может понадобиться `sleep_after` или retry после создания SA.
- [Образ Docker недоступен / drift тегов] → При необходимости pin известного tag в примерах README; задокументировать native Terraform fallback.

## Migration Plan

1. Настроить auth (`YC_TOKEN` / SA key, `YC_CLOUD_ID` при reuse, variables org/billing).
2. Предпочтительно: `docker pull stupean/yandex-terraform`, затем `docker run … -v "$(pwd)":/app` для `init` → `plan` → `apply` (local state, remote backend ещё нет).
3. Выгрузить static keys state SA; настроить backend; повторить через тот же образ с `terraform init -migrate-state`.
4. Проверить object state в bucket; дальнейшие apply используют remote state.
5. Rollback: destroy только если нет зависимостей; восстановление после неудачного migrate — из backup local state до migrate.

## Open Questions

- Точный набор ролей bootstrap SA vs cloud `admin` — уточнить при реализации по актуальному YC role reference, если создание каталогов требует cloud-level прав.
- Создавать ли сейчас shared state prefix для будущих env roots (`prod/terraform.tfstate`, …) или только bootstrap key — по умолчанию задокументировать convention префиксов без создания пустых objects.
