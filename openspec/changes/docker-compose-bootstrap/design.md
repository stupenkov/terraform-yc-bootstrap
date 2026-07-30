## Context

Уже есть Terraform bootstrap root (cloud/folders/IAM/bucket) и первая реализация Compose + `scripts/bootstrap.sh` + partial backend. Мотивация: см. proposal.md — Why. Требования: specs `compose-bootstrap`, delta `tfstate-backend`.

Ограничения: chicken-and-egg (bucket создаётся этим же root → первый apply local); кроссплатформенность = Docker на хосте, оркестрация в Linux-контейнере; образ `stupean/yandex-terraform` остаётся универсальным runtime. Code review выявил: пустые `${VAR:-}` в Compose `environment` затирают `env_file`; day-two `tf` без `init -backend-config`; resume по одному `tfstate_bucket` пропускает незавершённый apply; нет retry на IAM delay; образ без pin.

## Goals / Non-Goals

**Goals:**
- Compose как канонический операторский интерфейс на Win/macOS/Linux.
- One-shot `bootstrap` внутри контейнера: local apply → remote migrate.
- Partial backend + non-interactive migrate (`-force-copy`).
- Credentials без зависимости от bash `source` на хосте; `env_file` реально доходит до контейнера.
- Надёжный day-two и resume; pin образа.

**Non-Goals:**
- Перенос bootstrap-логики в сам Docker image (логика остаётся в репо).
- State locking (YDB) — по-прежнему follow-up.
- CI/CD pipeline в GitHub Actions в рамках этого change (Compose должен быть CI-friendly, но workflow не обязателен).
- Изменение структуры cloud/folders/IAM ролей (кроме формата credentials-файла при необходимости).

## Decisions

### Canonical interface: Docker Compose
- **Choice:** `docker-compose.yml` с сервисами `tf` (terraform entrypoint) и `bootstrap` (bash script), образ `stupean/yandex-terraform` **с pin tag/digest**, `volumes: .:/app`, `working_dir: /app`, опциональные `env_file` (`.env`, `.backend-credentials`), проброс host env без пустых override.
- **Why:** Compose нормализует mount paths лучше сырого `docker run` на Windows; одна команда на ОС.
- **Alternatives:** только документированный `docker run`; хостовый Node/Python wrapper.

### Compose credential passthrough (no empty override)
- **Choice:** не задавать в `environment:` ключи вида `${AWS_ACCESS_KEY_ID:-}` / `${YC_TOKEN:-}`, которые при отсутствии переменной становятся пустой строкой и **перебивают** `env_file`. Проброс с хоста — через `env_file`, project `.env` для interpolation только где нужно, и/или `docker compose run -e VAR` когда переменная реально задана. Допустимы явные pass-through только если Compose не материализует пустое значение (например, не дублировать AWS_* в `environment`, если они уже в `.backend-credentials`).
- **Why:** иначе day-two с ключами только в `.backend-credentials` ломается; README врёт.
- **Alternatives:** складывать AWS keys также в project `.env` (дублирование секретов); wrapper-скрипт на хосте.

### Bootstrap script lives in the repository
- **Choice:** `scripts/bootstrap.sh` + отдельный Compose-сервис `bootstrap` с `entrypoint: ["/bin/bash", "./scripts/bootstrap.sh"]`. Образ всегда делает `exec terraform "$@"`, поэтому `compose run tf ./scripts/bootstrap.sh` нельзя.
- **Why:** bootstrap-специфика рядом с `.tf`; сервис `tf` — для сырых terraform-команд.
- **Alternatives:** `--entrypoint /bin/bash` на каждый вызов; правка общего image.

### Partial backend configuration
- **Choice:** шаблон `backend.tf.in` (статика Yandex S3 без `bucket`/`key`). На migrate bootstrap копирует в gitignored `backend.tf` и передаёт `bucket`/`key` через `backend.hcl` + `-backend-config`. Local phase **не** держит `backend.tf`.
- **Why:** автоматизируемо; обходит chicken-and-egg; нет ручного placeholder.
- **Alternatives:** всегда закоммиченный `backend.tf` + hide/show; генерировать полный backend со вшитым bucket.

### Day-two init with backend.hcl
- **Choice:** day-two путь явно делает (или документирует обязательный) `terraform init -input=false -backend-config=backend.hcl` перед `plan`/`apply` для сервиса `tf`, когда remote уже используется. README не должен подразумевать, что достаточно только «тёплого» `.terraform/`. Опционально: тонкий wrapper/`compose run` helper или повторное использование логики init из bootstrap.
- **Why:** свежий checkout / удалённый `.terraform/` иначе падает на partial backend без bucket/key.
- **Alternatives:** закоммитить полный backend после первого apply (плохо для git); требовать только bootstrap для любых операций.

### Non-interactive migrate + retries
- **Choice:** `terraform init -migrate-state -force-copy` с `-backend-config=backend.hcl`; вокруг migrate — ограниченный retry/backoff при ошибках доступа к bucket (IAM propagation).
- **Why:** без TTY; переживает краткий 403 после создания static keys.
- **Alternatives:** sleep фиксированный N секунд один раз; только ручной повтор.

### Credentials for migrate inside the container
- **Choice:** bootstrap читает `terraform output -raw` keys (или уже выставленный env) **внутри** контейнера. Локальный файл — `KEY=VALUE` для Compose `env_file`.
- **Why:** хосту не нужен bash `source`.
- **Alternatives:** bash `export` файл.

### Apply approval UX
- **Choice:** plan по умолчанию; apply только при `BOOTSTRAP_AUTO_APPROVE=1`/`true`. Без сложного TTY-prompt на первой итерации.
- **Why:** безопасность + кроссплатформенность.
- **Alternatives:** всегда `-auto-approve`; двухшаговый UX без one-shot.

### Resume: complete apply before migrate
- **Choice:** если local state уже есть, перед migrate выполнять `plan` (и apply при auto-approve), а не skip’ать apply только из‑за непустого `tfstate_bucket`. Migrate — только когда apply успешен / нет незакрытых изменений, требующих apply.
- **Why:** оборванный apply после создания bucket иначе мигрирует неполный landing zone.
- **Alternatives:** оставить skip + надеяться на day-two (скрытый долг).

### Idempotency after migration
- **Choice:** детект remote S3 backend (`.terraform/terraform.tfstate` type s3 и/или успешный init с remote) → обычный plan/apply без local→remote migrate. При отсутствии meta, но наличии `backend.tf` + `backend.hcl`, предпочитать remote init, а не silent local recreate.
- **Why:** повторный bootstrap безопасен; потеря только `.terraform/` не должна сносить remote-first путь.
- **Alternatives:** отдельная команда migrate-once; fail если remote уже есть.

### Runtime image pin
- **Choice:** в `docker-compose.yml` указать явный tag (или digest) `stupean/yandex-terraform`; README — как обновить pin.
- **Why:** воспроизводимость и supply-chain.
- **Alternatives:** `:latest` с периодическим `pull` (текущий риск).

### Documentation
- **Choice:** README: prerequisites → tfvars → credentials → `docker compose run --rm bootstrap` → day-two с init/`backend.hcl` + `tf plan|apply`. Advanced: ручной migrate, `docker run`, native Terraform.
- **Why:** соответствует Compose-first цели; убирает устаревший `tf ./scripts/bootstrap.sh`.

## Risks / Trade-offs

- [Частичный сбой после apply до migrate] → resume завершает apply, затем migrate; README: не удалять local state до успеха migrate.
- [IAM delay на migrate] → retry/backoff; после исчерпания — ненулевой exit, local state сохранён.
- [Пустой Compose `environment` vs `env_file`] → не материализовать пустые AWS_*/YC_* в `environment`.
- [TTY/`-it` на Windows/CI] → `-force-copy` + явный auto-approve.
- [Compose только Engine без Compose v2] → prerequisite; raw `docker run` как fallback.
- [Sensitive outputs в логах] → не `echo` секреты.
- [Потеря `.terraform/` при живом remote state] → day-two/init с `backend.hcl` + credentials; не удалять `backend.tf` агрессивно, если remote уже ожидается.
- [Плавающий image tag] → pin tag/digest.
- [`-force-copy` при ошибочном local state] → не входить в migrate, если remote уже активен; осторожный детект.

## Migration Plan

1. Исправить Compose credential passthrough + pin образа.
2. Ужесточить `scripts/bootstrap.sh`: resume apply-before-migrate, migrate retries, аккуратнее remote detect / day-two init.
3. Обновить README (day-two init, env_file поведение, image pin).
4. Smoke: `compose run` с keys только в `.backend-credentials`; повторный bootstrap после migrate.
5. Rollback планировочных фиксов: откат compose/script/README; облачная инфра не затрагивается.

## Open Questions

- Какой именно tag/digest образа зафиксировать сейчас — взять текущий latest digest с Docker Hub при apply, либо semver tag если опубликован.
