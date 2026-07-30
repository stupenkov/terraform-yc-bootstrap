## Purpose

Создаёт service accounts и IAM role bindings, необходимые для bootstrap структуры облака, управления каталогами окружений и доступа к хранилищу Terraform state с least privilege.

## ADDED Requirements

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
