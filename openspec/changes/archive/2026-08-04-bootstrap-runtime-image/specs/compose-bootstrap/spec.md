## MODIFIED Requirements

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

## ADDED Requirements

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
