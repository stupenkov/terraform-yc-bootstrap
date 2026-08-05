## ADDED Requirements

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
