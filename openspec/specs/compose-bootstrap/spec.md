# compose-bootstrap Specification

## Purpose

Кроссплатформенный Docker Compose workflow для запуска Terraform bootstrap и автоматической миграции local state в Object Storage без хостового bash.

## Requirements

### Requirement: Compose is the primary operator interface
Репозиторий SHALL предоставлять два поддерживаемых operator interface:

1. **Consumer happy path:** `docker run` с публикуемым bootstrap-образом (запечённый модуль) — без обязательного `git clone`.
2. **Developer path:** Docker Compose на checkout репозитория, монтирующий корень репо и использующий base/runtime образ (или тот же bootstrap-образ в режиме volume-over-bake, если так задокументировано), с Terraform working directory = `terraform/` и скриптами из `scripts/`, для итерации над модулем.

Compose-путь SHALL по-прежнему пробрасывать credentials (`YC_TOKEN` и/или `YC_SERVICE_ACCOUNT_KEY_FILE`, при необходимости AWS-совместимые ключи для backend) так, чтобы оператор на Windows, macOS и Linux мог запускать Terraform Compose-командой без установки Terraform на хост. Compose не SHALL быть удалён этим изменением.

#### Scenario: Plan via Compose on any host OS
- **WHEN** оператор выполнил `docker compose run --rm <service> plan` при наличии валидных YC credentials в окружении и заполненных Terraform inputs (`.env` / `TF_VAR_*` или `terraform.tfvars`)
- **THEN** Terraform plan выполняется внутри контейнера против конфигурации в `terraform/`
- **AND** хостовый Terraform не требуется

#### Scenario: Day-two apply via Compose
- **WHEN** remote backend уже настроен и state находится в Object Storage
- **AND** доступны partial backend config (`backend.hcl` с `bucket`/`key`) и AWS-совместимые credentials для Object Storage
- **THEN** оператор может выполнить plan/apply через Compose против remote state
- **AND** это SHALL работать после явного `init -backend-config=backend.hcl` (или эквивалента, встроенного в задокументированный day-two путь), а не только при «тёплом» `.terraform/` от предыдущего migrate

#### Scenario: Consumer uses docker run without clone
- **WHEN** оператор-потребитель следует README happy path с `docker run` и bootstrap-образом
- **THEN** bootstrap или join выполняется без checkout git-репозитория на хосте
- **AND** Compose не обязателен для этого сценария

### Requirement: README documents dual operator paths
README SHALL явно разделять consumer-путь (`docker run` + образ) и developer-путь (`git clone` + `docker compose`), чтобы не смешивать требования clone с минимальным onboarding.

#### Scenario: New reader finds consumer path first
- **WHEN** оператор открывает README для первого запуска landing zone
- **THEN** первым (или явно помеченным primary) описан путь без clone через `docker run`
- **AND** Compose-путь описан как вариант для разработки/изменения модуля в репозитории

### Requirement: Repository directories separate module scripts and packaging
Репозиторий SHALL разделять Terraform root (`terraform/`), orchestration (`scripts/`), Docker packaging (`docker/`, `Dockerfile`) и справочные examples (`examples/`), чтобы developer Compose и сборка образа использовали одни и те же пути без плоского корня из смеси `.tf` и packaging-файлов.

#### Scenario: Developer compose uses terraform subdirectory
- **WHEN** разработчик запускает Compose-сервис bootstrap/tf/join из checkout
- **THEN** Terraform working directory указывает на `terraform/`
- **AND** entrypoint скриптов указывает на `scripts/bootstrap.sh` или `scripts/join.sh`

### Requirement: Compose env_file credentials are not overridden by empty defaults
Compose-конфигурация SHALL пробрасывать credentials из optional `env_file` (`.env`, `.backend-credentials`) в контейнер так, чтобы отсутствие одноимённых переменных в shell хоста не подставляло пустые значения, затирающие `env_file`.

#### Scenario: AWS keys from .backend-credentials alone
- **WHEN** файл `.backend-credentials` содержит `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY`
- **AND** эти переменные не экспортированы в shell хоста
- **THEN** контейнер сервиса `tf` / `bootstrap` получает непустые значения из `env_file`
- **AND** day-two plan/apply к S3 backend может аутентифицироваться этими ключами

#### Scenario: YC token from project .env alone
- **WHEN** project `.env` содержит `YC_TOKEN` (или путь к SA key настроен согласно README)
- **AND** оператор не экспортировал ту же переменную отдельно в shell
- **THEN** контейнер получает credential и bootstrap/Terraform могут аутентифицироваться в Yandex Cloud

### Requirement: One-shot bootstrap migrates state automatically
Репозиторий SHALL предоставлять Compose-совместимую bootstrap-команду (скрипт, исполняемый внутри контейнера), которая выполняет первичный apply с local state и затем мигрирует state в созданный Object Storage bucket без ручного копирования `backend.tf.example` и без bash `source` на хосте.

#### Scenario: Fresh bootstrap completes with remote state
- **WHEN** оператор запускает bootstrap-команду через Docker Compose при валидных prerequisites (Docker, credentials, `terraform.tfvars`)
- **THEN** landing-zone ресурсы создаются (или обновляются) через Terraform apply
- **AND** bootstrap state переносится в Object Storage
- **AND** последующий plan через Compose использует remote state

#### Scenario: Host does not run shell orchestration
- **WHEN** bootstrap-команда выполняется
- **THEN** оркестрация init/apply/migrate происходит внутри контейнера
- **AND** от оператора на хосте не требуется выполнять `source` credentials-файла или вручную подставлять имя bucket в backend-файл

### Requirement: Bootstrap is safely re-runnable after migration
Bootstrap-команда SHALL корректно обрабатывать повторный запуск после успешной миграции: не требовать повторной миграции с local state, если remote backend уже активен.

#### Scenario: Second bootstrap after remote state exists
- **WHEN** state уже хранится в Object Storage и оператор снова запускает bootstrap-команду
- **THEN** команда не пытается мигрировать несуществующий local-only state как первичный bootstrap
- **AND** выполняет безопасный Terraform workflow поверх уже настроенного remote backend (plan/apply или эквивалент без разрушения remote state)

### Requirement: Runtime image is pinned
Compose-файл SHALL ссылаться на образ `stupean/yandex-terraform` с зафиксированным tag или digest, а не на плавающий неявный `latest` без pin.

#### Scenario: Compose references a pinned image
- **WHEN** оператор выполняет `docker compose pull` / `docker compose run`
- **THEN** используемый image reference включает явный tag или digest
- **AND** README указывает, как обновить pin при необходимости
