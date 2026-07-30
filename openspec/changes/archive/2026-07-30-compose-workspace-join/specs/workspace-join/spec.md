## Purpose

Позволяет второму и следующим разработчикам через Docker Compose подключиться к уже созданной bootstrap landing zone с минимумом ручных шагов (в happy path — только `YC_TOKEN`): discovery workspace, локальный backend-конфиг, remote Terraform state без повторного create cloud.

## ADDED Requirements

### Requirement: Compose join is the secondary operator path
Репозиторий SHALL предоставлять Docker Compose сервис `join` (attach-only) на том же runtime-образе, что и bootstrap. Join SHALL NEVER выполнять первичный create cloud / local bootstrap apply.

#### Scenario: Join via Compose
- **WHEN** оператор с валидным `YC_TOKEN` (или SA key) выполнил Compose join-команду
- **AND** workspace однозначно определён (discovery или явный указатель)
- **THEN** локально появляются `backend.tf` и `backend.hcl` для remote state
- **AND** выполняется успешный `terraform init` с `-backend-config` к Object Storage
- **AND** последующий plan отражает уже существующую инфраструктуру, а не план создания нового облака с нуля

#### Scenario: Join does not recreate cloud
- **WHEN** join завершается успешно
- **THEN** команда не создаёт новое облако и не делает первичный local-only apply landing zone
- **AND** оператору не требуется копировать `backend.tf` / `backend.hcl` с машины первого разработчика

### Requirement: Smart bootstrap chooses create vs attach
Команда Compose `bootstrap` на машине без активного remote backend SHALL пытаться обнаружить существующий workspace через Yandex Cloud API. При ровно одном кандидате SHALL выполнить attach (тот же исход, что join). При нуле кандидатов SHALL выполнять первичный create/migrate flow. При нескольких кандидатах SHALL завершиться ошибкой с требованием задать `TFSTATE_BUCKET` (или эквивалентный явный указатель), а не создавать новое облако.

#### Scenario: Second developer runs bootstrap with only YC_TOKEN
- **WHEN** на чистой машине в `.env` задан только `YC_TOKEN` (и при необходимости org-scoped доступ)
- **AND** в доступных cloud/folders существует ровно один bootstrap workspace с meta
- **AND** оператор выполняет `docker compose run --rm bootstrap`
- **THEN** выполняется attach к remote state (backend files + credentials + init)
- **AND** не создаётся второе облако

#### Scenario: Ambiguous discovery refuses create
- **WHEN** discovery находит ноль или более одного workspace
- **AND** явный `TFSTATE_BUCKET` (или задокументированный указатель) не задан
- **THEN** bootstrap/join не создаёт новую landing zone вслепую
- **AND** сообщает, как задать явный указатель

### Requirement: Workspace discovery is primary over manual bucket handoff
Определение state bucket для attach SHALL в первую очередь использовать discovery через Yandex Cloud API под credentials оператора. Явное имя bucket (`TFSTATE_BUCKET` или эквивалент) и/или `TF_VAR_cloud_id` SHALL быть fallback для disambiguation, а не обязательным happy-path handoff.

#### Scenario: Auto-discover single workspace
- **WHEN** API-доступный набор содержит ровно один bucket/workspace с задокументированным meta-object
- **THEN** join/smart-bootstrap использует его без предварительной передачи имени bucket от первого разработчика

#### Scenario: Explicit bucket overrides ambiguity
- **WHEN** задан `TFSTATE_BUCKET`
- **THEN** attach использует этот bucket для чтения meta и init
- **AND** discovery не обязан угадывать среди нескольких кандидатов

### Requirement: Workspace meta is fetched from Object Storage
Attach/join SHALL читать несекретный workspace meta-object из state bucket и использовать его для заполнения `backend.hcl` (bucket, key) и значений вроде `cloud_id` / folder ids.

#### Scenario: Meta drives local backend files
- **WHEN** meta-object доступен в bucket по задокументированному ключу
- **THEN** записываются `backend.hcl` с bucket и state key из meta
- **AND** устанавливается `backend.tf` из шаблона репозитория при отсутствии файла

### Requirement: State credentials without Lockbox
Attach/join SHALL получить AWS-совместимые credentials для S3 backend без Yandex Lockbox: либо использовать уже заданные `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, либо создать новый static access key для service account tfstate через Yandex Cloud API под credentials оператора и записать их только в локальный ignored файл.

#### Scenario: Mint new static key on join
- **WHEN** в окружении нет AWS keys
- **AND** оператор имеет право создать static access key для SA tfstate (id из meta)
- **THEN** создаётся новый key pair и сохраняется локально в формате env-file `KEY=VALUE`
- **AND** secret не публикуется в git и не записывается в открытый meta-object в bucket

#### Scenario: Reuse AWS keys from env
- **WHEN** `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY` уже заданы (например в `.env`)
- **THEN** новый static key не обязателен
- **AND** эти значения используются для `terraform init` к remote backend

### Requirement: Lockbox is out of scope
Workspace join/attach и публикация meta SHALL NOT зависеть от Yandex Lockbox.

#### Scenario: No Lockbox prerequisite
- **WHEN** оператор выполняет join или smart attach через bootstrap
- **THEN** успешный путь не требует создания или чтения Lockbox secret
