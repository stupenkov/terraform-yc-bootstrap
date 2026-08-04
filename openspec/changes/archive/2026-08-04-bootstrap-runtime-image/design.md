## Context

Сейчас оператор всегда клонирует репозиторий: Compose монтирует `.` в `/app` и запускает Terraform/скрипты из **плоского** корня (все `*.tf` рядом с compose/README). Runtime-пин — `stupean/yandex-terraform@sha256:…` (только Terraform + инструменты, без модуля). Join/discovery и smart bootstrap уже есть в `scripts/`. См. proposal.md — Why.

Ограничения: Lockbox не используется; кроссплатформенность через Docker; секреты только через env / локальные gitignored файлы.

## Goals / Non-Goals

**Goals:**

- Один `docker run` для bootstrap/join без clone.
- Понятная раскладка репозитория: модуль / скрипты / docker-упаковка / examples.
- Git-репозиторий остаётся source of truth; образ собирается из него.
- Compose-путь для разработчиков сохраняется (с новым `working_dir`).
- Совместимость с существующим discovery / mint keys / `workspace.json`.

**Non-Goals:**

- Интерактивный wizard получения `YC_TOKEN` / org IDs.
- Удаление Compose или отказ от volume-mount разработки.
- Публикация секретов в образ или в Object Storage.
- Обязательный CI publish в этом change (достаточно Dockerfile + документированный ручной/будущий publish; CI можно добавить отдельно).
- Смена облачной модели (folders, SA, bucket).

## Decisions

### 1. Repo layout

Целевое дерево:

```
.
├── README.md
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .env.example
├── docker/
│   └── entrypoint.sh
├── terraform/                 # root module
│   ├── *.tf
│   └── backend.tf.in
├── scripts/
│   ├── bootstrap.sh
│   ├── join.sh
│   └── lib/
└── examples/
    ├── backend.tf.example
    └── terraform.tfvars.example
```

- **`terraform/`** — единственный Terraform root (то, что попадает в образ как `/module`).
- **`scripts/`** — orchestration (рядом с модулем в репо; в образе копируются вместе с модулем или в `/module/scripts`).
- **`docker/`** — entrypoint и всё, что относится к упаковке образа.
- **`examples/`** — справочные файлы, не обязательны в runtime-образе.
- Корень: только packaging + docs + env example.

**Альтернатива:** имя каталога `module/` вместо `terraform/` — отвергнуто: `terraform/` однозначнее для читателя репо; внутри контейнера путь остаётся `/module` (короткий bake-path).

### 2. Отдельный bootstrap-образ поверх base runtime

- **Решение:** `Dockerfile` `FROM stupean/yandex-terraform@<pinned-digest>`, `COPY terraform/` → `/module`, `COPY scripts/` → `/module/scripts`, `COPY docker/entrypoint.sh`. Entrypoint диспатчит `bootstrap` | `join` | остальное → `terraform "$@"`.
- **Имя образа (рабочее):** `stupean/terraform-yc-bootstrap`, теги = semver / git tag / digest.
- **Альтернативы:** (a) только Compose — отвергнуто (нужен clone); (b) один раздутый образ вместо base+app — хуже кэш.

### 3. Working directory и optional volume

- **Решение:** модуль в образе — `/module`; writable workspace — `/work`.
  - Без `-v`: `/work` ephemeral.
  - С `-v "$PWD:/work"`: persist `backend.hcl`, credentials, `.terraform/`.
- Entrypoint: sync/copy `/module` → `/work` если в `/work` ещё нет модуля; иначе использовать содержимое `/work` (в т.ч. developer override). Скрипты пишут артефакты в `/work`.
- **Альтернатива:** всегда требовать volume — проще, но ломает «без файлов на хосте».

### 4. Dual path: consumer vs developer

| Роль | Команда | Откуда `.tf` |
|------|---------|--------------|
| Consumer | `docker run … bootstrap` | из образа (`/module`) |
| Developer | `docker compose run …` | volume `.:/app`, `working_dir: /app/terraform`, скрипты `/app/scripts/…` |

Compose на первой поставке может остаться на base `yandex-terraform` + mount организованного дерева; опционально позже — тот же bootstrap-образ.

### 5. Credentials

- `YC_TOKEN` / `TF_VAR_*` / optional `AWS_*` через `-e` или `--env-file`.
- `.env.example` остаётся в **корне** репо (удобно для `--env-file` и Compose `env_file`).

### 6. Versioning

- README pin: digest или immutable tag.
- Содержимое модуля в образе = commit сборки.

## Risks / Trade-offs

- **[Risk] Ломаются привычные пути (`*.tf` в корне)** → Mitigation: один PR/change с `git mv` + обновление README/compose; в Notes указать новый root.
- **[Risk] Расхождение compose-mount vs bake** → Mitigation: один набор `terraform/` + `scripts/`; образ копирует те же пути.
- **[Risk] Скрипты завязаны на cwd** → Mitigation: entrypoint / `WORK_DIR` нормализуют cwd до `/work` (или `/app/terraform` в Compose).
- **[Risk] Ephemeral без volume** → Mitigation: документировать `-v` для day-two.
- **[Trade-off] Версия инфры = версия образа** — цель варианта B.

## Migration Plan

1. Реорганизовать каталоги (`git mv` в `terraform/`, `examples/`, добавить `docker/`).
2. Обновить Compose (`working_dir`, entrypoint paths) и скрипты под новый root.
3. Добавить `Dockerfile` + entrypoint; собрать локально; прогнать bootstrap/join.
4. Обновить README: consumer `docker run` первым; Compose — для разработки.
5. Опубликовать образ (вручную или follow-up CI); зафиксировать digest в README.
6. Rollback: git history сохраняет старые пути; Compose-путь после миграции — единственный supported developer path.

## Open Questions

- Точное имя репозитория на Docker Hub (`stupean/terraform-yc-bootstrap` vs другое) — зафиксировать при первой публикации.
- Нужен ли сразу GitHub Action на publish — вне минимального scope.
