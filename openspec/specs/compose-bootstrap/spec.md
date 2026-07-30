# compose-bootstrap Specification

## Purpose

Кроссплатформенный Docker Compose workflow для запуска Terraform bootstrap и автоматической миграции local state в Object Storage без хостового bash.

## Requirements

### Requirement: Compose is the primary operator interface
Репозиторий SHALL предоставлять Docker Compose сервис на образе `stupean/yandex-terraform`, монтирующий корень репозитория и пробрасывающий credentials (`YC_TOKEN` и/или `YC_SERVICE_ACCOUNT_KEY_FILE`, при необходимости AWS-совместимые ключи для backend), так чтобы оператор на Windows, macOS и Linux мог запускать Terraform одной Compose-командой без установки Terraform на хост.

#### Scenario: Plan via Compose on any host OS
- **WHEN** оператор выполнил `docker compose run --rm <service> plan` при наличии валидных YC credentials в окружении и заполненного `terraform.tfvars`
- **THEN** Terraform plan выполняется внутри контейнера против смонтированной конфигурации
- **AND** хостовый Terraform не требуется

#### Scenario: Day-two apply via Compose
- **WHEN** remote backend уже настроен и state находится в Object Storage
- **AND** доступны partial backend config (`backend.hcl` с `bucket`/`key`) и AWS-совместимые credentials для Object Storage
- **THEN** оператор может выполнить plan/apply через Compose против remote state
- **AND** это SHALL работать после явного `init -backend-config=backend.hcl` (или эквивалента, встроенного в задокументированный day-two путь), а не только при «тёплом» `.terraform/` от предыдущего migrate

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
