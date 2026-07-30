## Purpose

Предоставляет Yandex Object Storage, пригодный для Terraform S3-compatible remote backend, чтобы bootstrap и будущие roots хранили state централизованно, а не только на диске.

## ADDED Requirements

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
Bootstrap root SHALL поддерживать первичный apply с local state, затем документированную миграцию этого state в созданный bucket без пересоздания ресурсов.

#### Scenario: Migrate local state to remote backend
- **WHEN** state bucket уже существует после apply с local state
- **AND** оператор настраивает S3 backend и выполняет `terraform init -migrate-state`
- **THEN** существующий bootstrap state переносится в Object Storage
- **AND** последующие plan используют remote state

### Requirement: State access credentials are provisioned
Конфигурация bootstrap SHALL создать static access keys (или эквивалентные задокументированные credentials) для service account, который может читать и писать objects в state bucket, без коммита секретов в git.

#### Scenario: Access key material is operator-facing only
- **WHEN** Terraform apply создаёт credentials для state bucket
- **THEN** access key ID и secret доступны только через Terraform sensitive outputs или локальный ignored file
- **AND** secrets не записываются в отслеживаемые файлы репозитория
