# bootstrap-iam Specification

## Purpose

Создаёт service accounts и IAM role bindings, необходимые для bootstrap структуры облака, управления каталогами окружений и доступа к хранилищу Terraform state с least privilege.

## Requirements

### Requirement: Bootstrap service account exists
Конфигурация bootstrap SHALL создать service account для управления структурой облака и общими platform-ресурсами с ролями, достаточными для администрирования каталогов и Object Storage в каталоге `platform` (и cloud-level управления каталогами при необходимости).

#### Scenario: Bootstrap SA after apply
- **WHEN** Terraform apply завершается успешно
- **THEN** существует bootstrap service account
- **AND** его ID доступен как output
- **AND** ему назначены роли, определённые для bootstrap-администрирования

### Requirement: State access service account exists
Конфигурация bootstrap SHALL создать service account, предназначенный для доступа Object Storage к Terraform remote state, с ролями, ограниченными необходимым для state bucket (как минимум storage editor на каталог `platform` или эквивалентный bucket-scoped доступ).

#### Scenario: State SA roles
- **WHEN** Terraform apply завершается успешно
- **THEN** существует state-access service account
- **AND** он может читать и писать objects, используемые как Terraform state в state bucket
- **AND** ему по умолчанию не выдаётся широкий admin на каталоги окружений, если это явно не настроено

### Requirement: Per-environment Terraform service accounts exist
Конфигурация bootstrap SHALL создать service account на каждый каталог окружения (`prod`, `stage`, `dev`) с ролью editor (или настраиваемой) только на этот каталог — для последующих Terraform roots окружений.

#### Scenario: Environment SA isolation
- **WHEN** Terraform apply завершается успешно
- **THEN** у каждого каталога окружения есть связанный service account
- **AND** этот service account имеет права управления на свой каталог
- **AND** по умолчанию этот service account не получает editor на другие каталоги окружений

### Requirement: IAM bindings use additive members
Конфигурация bootstrap SHALL назначать роли через additive IAM member resources (не authoritative policy replace), чтобы существующие bindings на organization или cloud не затирались.

#### Scenario: Additive role assignment
- **WHEN** IAM-роли применяются к service accounts
- **THEN** добавляются bindings для нужных members и ролей
- **AND** несвязанные существующие access bindings на том же cloud или folder остаются нетронутыми

### Requirement: Per-environment Terraform SA authorized keys
Конфигурация bootstrap SHALL создать Yandex IAM authorized key для каждого per-environment service account (`terraform-prod`, `terraform-stage`, `terraform-dev`), чтобы оператор мог аутентифицировать Terraform provider или CI от имени этого SA без ручного выпуска ключа вне модуля.

#### Scenario: Authorized keys after apply
- **WHEN** Terraform apply завершается успешно
- **THEN** для каждого env Terraform SA существует authorized key
- **AND** private key material доступен через sensitive Terraform outputs
- **AND** material не публикуется в git и не записывается как отдельный plaintext object в state bucket

#### Scenario: Optional local key files
- **WHEN** включена запись локальных key-файлов (аналог `write_backend_credentials`)
- **THEN** для каждого env SA создаётся ignored JSON-файл, пригодный для `YC_SERVICE_ACCOUNT_KEY_FILE`
- **AND** файлы не входят в отслеживаемые пути репозитория

### Requirement: Bootstrap and tfstate SA keys unchanged by this capability
Конфигурация bootstrap SHALL NOT обязана выпускать authorized key для SA `bootstrap` или заменять static access key SA `tfstate` authorized key: env SA keys обслуживают Yandex provider для каталогов окружений; доступ к Object Storage state по-прежнему через AWS-compatible static keys.

#### Scenario: Scope limited to env SA
- **WHEN** apply создаёт authorized keys по этому требованию
- **THEN** ключи выпускаются только для `terraform-{prod,stage,dev}`
- **AND** существующий путь static keys для SA `tfstate` сохраняется
