# tfstate-backend Specification

## Purpose

Предоставляет Yandex Object Storage, пригодный для Terraform S3-compatible remote backend, чтобы bootstrap и будущие roots хранили state централизованно, а не только на диске.

## Requirements

### Requirement: State bucket is created in the platform folder
Конфигурация bootstrap SHALL создать Object Storage bucket в каталоге `platform` для хранения файлов Terraform state.

#### Scenario: Bucket created after apply
- **WHEN** Terraform apply для bootstrap root завершается успешно
- **THEN** в каталоге `platform` существует Object Storage bucket
- **AND** имя bucket доступно как output

### Requirement: Bucket is suitable for Terraform remote state
Конфигурация bootstrap SHALL сформировать настройки bucket, совместимые с Yandex Cloud S3 Terraform backend (`storage.yandexcloud.net`), включая документацию или outputs для пути backend `key`, используемого этим bootstrap root.

#### Scenario: Backend parameters are exposed
- **WHEN** Terraform apply завершается успешно
- **THEN** outputs включают имя bucket и рекомендуемый state object key для bootstrap root
- **AND** документация описывает endpoint S3 backend и необходимые skip_* flags для Yandex Object Storage

### Requirement: Initial apply then remote migration
Bootstrap root SHALL поддерживать первичный apply с local state, затем миграцию этого state в созданный bucket без пересоздания ресурсов. Миграция SHALL быть доступна через автоматизированный Docker Compose bootstrap entrypoint и MAY оставаться задокументированной как ручной advanced-путь. Automated bootstrap SHALL мигрировать только после завершённого apply относительно текущего local state (наличие output `tfstate_bucket` само по себе недостаточно, если plan ещё показывает незакрытые изменения).

#### Scenario: Migrate local state to remote backend via automation
- **WHEN** state bucket уже существует после apply с local state
- **AND** оператор запускает Compose bootstrap-команду (или эквивалентный контейнерный migrate-шаг)
- **THEN** существующий bootstrap state переносится в Object Storage без ручной правки backend-файла на хосте
- **AND** последующие plan используют remote state

#### Scenario: Resume does not migrate incomplete apply
- **WHEN** local state уже содержит bucket (например apply оборвался после его создания)
- **AND** относительно local state ещё есть незакрытые изменения
- **THEN** bootstrap сначала завершает apply (при `BOOTSTRAP_AUTO_APPROVE`) либо останавливается на plan
- **AND** migrate выполняется только после успешного apply без оставшихся обязательных изменений

#### Scenario: Manual migrate remains possible
- **WHEN** оператор предпочитает ручной путь
- **THEN** документация описывает partial backend configuration, credentials и `terraform init -migrate-state` (включая `-force-copy` для non-interactive режима)

### Requirement: State access credentials are provisioned
Конфигурация bootstrap SHALL создать static access keys (или эквивалентные задокументированные credentials) для service account, который может читать и писать objects в state bucket, без коммита секретов в git. Локальный credentials-файл, если создаётся, SHALL использовать формат, пригодный для Docker `--env-file` / Compose `env_file` (`KEY=VALUE`), а не bash-only `export`/`source`.

#### Scenario: Access key material is operator-facing only
- **WHEN** Terraform apply создаёт credentials для state bucket
- **THEN** access key ID и secret доступны через Terraform sensitive outputs и/или локальный ignored file
- **AND** secrets не записываются в отслеживаемые файлы репозитория

#### Scenario: Credentials work without host bash source
- **WHEN** локальный credentials-файл включён (`write_backend_credentials`)
- **THEN** файл содержит `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY` в формате `KEY=VALUE`
- **AND** контейнерный bootstrap/migrate путь может использовать эти значения без выполнения bash `source` на хосте

### Requirement: Partial S3 backend configuration
Bootstrap root SHALL поставлять S3 backend configuration в partial-виде: статические параметры Yandex Object Storage (endpoint, region, skip_* flags) в репозитории, а динамические `bucket` и `key` — через `-backend-config` (или эквивалент) на этапе migrate/init после появления bucket.

#### Scenario: Backend enabled without editing bucket placeholder
- **WHEN** оператор или bootstrap-скрипт инициализирует remote backend после первого apply
- **THEN** имя bucket и state key передаются через backend-config, а не через ручную правку placeholder в скопированном example-файле
- **AND** endpoint остаётся `https://storage.yandexcloud.net` с необходимыми skip_* flags

### Requirement: Automated migrate tolerates brief access failures
Automated migrate SHALL повторять ограниченное число попыток `terraform init -migrate-state` (или эквивалента) при кратковременных ошибках доступа к Object Storage (например IAM/propagation delay после создания static keys), с backoff между попытками, прежде чем завершиться ошибкой.

#### Scenario: Migrate retries then succeeds
- **WHEN** первая попытка migrate получает временный отказ доступа к bucket сразу после apply
- **AND** последующая попытка в пределах лимита retries успешна
- **THEN** bootstrap завершается с активным remote backend без ручного вмешательства

#### Scenario: Migrate fails after retries exhausted
- **WHEN** все попытки migrate исчерпаны с ошибкой доступа
- **THEN** bootstrap завершается с ненулевым кодом и сохраняет local state для повторного запуска

### Requirement: Workspace meta object is published after migrate
После успешной миграции bootstrap state в Object Storage система SHALL записать в тот же state bucket несекретный workspace meta-object по задокументированному object key. Meta SHALL включать как минимум: cloud_id, folder_ids, bucket name, bootstrap state key, id service account tfstate. Meta MUST NOT содержать static secret keys, IAM tokens или содержимое `.backend-credentials`.

#### Scenario: Meta written after successful migrate
- **WHEN** automated bootstrap успешно завершает `init -migrate-state` в state bucket
- **THEN** в bucket существует meta-object с cloud_id, folder_ids, bucket, state key и tfstate SA id
- **AND** object не содержит AWS secret access key или YC token

#### Scenario: Meta is readable for join
- **WHEN** оператор или join/attach-команда читает meta-object с валидными правами на bucket
- **THEN** данных достаточно, чтобы сформировать `backend.hcl` и знать, для какого SA выпускать static keys

#### Scenario: Meta supports IAM-based discovery
- **WHEN** attach выполняет discovery под `YC_TOKEN` без заранее известных AWS keys
- **THEN** наличие meta-object в bucket является критерием «это bootstrap workspace»
- **AND** содержимое meta читается способом, не требующим Lockbox (YC Object Storage API / эквивалент с IAM token или последующий S3 get после mint keys)

### Requirement: No secret material in open bucket objects for credentials sharing
Bootstrap и связанные automation paths SHALL NOT использовать Yandex Lockbox и SHALL NOT хранить state-access secret keys в публично читаемых (для всех с list/get на bucket) «credentials» objects как замену локальному ignored файлу. Локальный `.backend-credentials` остаётся operator-facing only.

#### Scenario: Credentials stay local or freshly minted
- **WHEN** нужны AWS-совместимые keys для S3 backend на новой машине
- **THEN** они берутся из локального env/файла или создаются заново для SA tfstate
- **AND** не восстанавливаются из открытого plaintext object, предназначенного как «shared secrets store» в том же bucket

### Requirement: Operator secrets may reside in Terraform state
Bootstrap MAY хранить operator-facing secret material (включая authorized key private keys env SA и static keys SA `tfstate`) внутри Terraform state, размещённого в state bucket каталога `platform`. Это SHALL NOT считаться нарушением запрета на plaintext shared credentials objects: state — единственный допустимый remote store секретов bootstrap без Lockbox при модели доступа «только DevOps / peer-операторы landing zone».

#### Scenario: Secrets in state are expected
- **WHEN** apply создаёт sensitive credentials (static keys или authorized keys)
- **THEN** private material присутствует в Terraform state после migrate в Object Storage
- **AND** оператор MAY извлекать его через sensitive outputs или `terraform state` / `terraform output`
- **AND** bootstrap SHALL NOT дублировать тот же material отдельным credentials object в bucket для «скачать секрет из S3»

#### Scenario: Open credentials objects remain forbidden
- **WHEN** нужны shared credentials для нескольких машин
- **THEN** система по-прежнему SHALL NOT класть secret keys в открытый plaintext object рядом с `workspace.json`
- **AND** новый оператор landing zone получает AWS keys локально (env / mint), а env SA JSON — от DevOps через output/state или handoff вне bucket
