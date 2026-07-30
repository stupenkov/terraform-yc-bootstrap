## Purpose

Определяет layout landing zone в Yandex Cloud: управляемое облако с каталогами окружений и выделенным каталогом `platform` для общих ресурсов, включая хранение Terraform state.

## ADDED Requirements

### Requirement: Cloud is available for folder placement
Конфигурация bootstrap SHALL создать новое облако Yandex Cloud в указанной organization либо SHALL переиспользовать существующее облако, если передан existing cloud ID, так чтобы все каталоги создавались ровно в одном облаке.

#### Scenario: Create new cloud
- **WHEN** оператор передаёт organization ID и billing account ID и не передаёт existing cloud ID
- **THEN** Terraform создаёт облако в этой organization, привязанное к billing account
- **AND** cloud ID доступен как output

#### Scenario: Reuse existing cloud
- **WHEN** оператор передаёт existing cloud ID
- **THEN** Terraform не создаёт новое облако
- **AND** каталоги создаются в указанном облаке

### Requirement: Environment folders exist
Конфигурация bootstrap SHALL создать каталоги с именами `prod`, `stage` и `dev` в целевом облаке.

#### Scenario: Apply creates environment folders
- **WHEN** Terraform apply для bootstrap root завершается успешно
- **THEN** в целевом облаке существуют каталоги `prod`, `stage` и `dev`
- **AND** ID каждого каталога доступен как output

### Requirement: Platform folder exists
Конфигурация bootstrap SHALL создать выделенный каталог (имя по умолчанию `platform`) в целевом облаке для общих platform-ресурсов, включая Object Storage для Terraform state (и будущую shared infrastructure).

#### Scenario: Apply creates platform folder
- **WHEN** Terraform apply для bootstrap root завершается успешно
- **THEN** в целевом облаке существует каталог `platform` для общих platform-ресурсов
- **AND** его folder ID доступен как output

### Requirement: Folder names are configurable with safe defaults
Конфигурация bootstrap SHALL позволять переопределять отображаемые имена каталогов через variables при defaults `prod`, `stage`, `dev` и `platform`.

#### Scenario: Custom folder names
- **WHEN** оператор задаёт custom variables имён каталогов
- **THEN** Terraform создаёт каталоги с этими именами вместо defaults
