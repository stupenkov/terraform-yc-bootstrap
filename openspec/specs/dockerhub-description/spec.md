# dockerhub-description Specification

## Purpose

Автоматическая синхронизация short и full description репозитория Docker Hub с документацией в git, чтобы страница образа на Hub отражала актуальный quick start без ручного копирования.

## Requirements

### Requirement: Full description synced from repository README
Система SHALL обновлять full description (Overview) Docker Hub репозитория `stupean/terraform-yc-bootstrap` содержимым корневого `README.md` из git (или явно указанного эквивалентного documented path в том же репозитории).

#### Scenario: README content appears on Hub Overview
- **WHEN** выполняется успешная синхронизация описания
- **THEN** full description на Hub содержит текст из синхронизированного README
- **AND** обновление выполняется без ручного редактирования в Docker Hub UI

### Requirement: Short description is set on Hub
Система SHALL задавать short description репозитория на Docker Hub краткой строкой (из description GitHub-репозитория или зафиксированного documented значения), укладывающейся в ограничения Hub.

#### Scenario: Short description updated with sync
- **WHEN** выполняется успешная синхронизация описания
- **THEN** short description на Hub непустое (в пределах лимита Hub)
- **AND** отражает назначение образа bootstrap landing zone

### Requirement: Sync on README changes to main
Система SHALL запускать синхронизацию описания при push в ветку `main`, если изменился файл README, используемый как источник full description.

#### Scenario: Docs-only push updates Hub
- **WHEN** в `main` попадает commit, меняющий корневой `README.md`
- **THEN** запускается job синхронизации описания Hub
- **AND** для этого не требуется новый релиз образа

### Requirement: Sync after successful image publish
Система SHALL запускать синхронизацию описания Hub после успешной публикации образа в Docker Hub (релизный publish и manual republish), чтобы Overview не оставался пустым после появления/обновления образа.

#### Scenario: Release publish refreshes Overview
- **WHEN** образ успешно запушен в Docker Hub релизным или republish-процессом
- **THEN** в том же успешном контуре (или непосредственно следующим шагом) обновляется описание Hub
- **AND** сбой sync description MUST NOT откатывать уже выполненный push образа (ошибка sync видима отдельно)

### Requirement: Explicit Hub repository identity
Синхронизация SHALL нацеливаться на Docker Hub репозиторий `stupean/terraform-yc-bootstrap`, а не на имя GitHub-репозитория по умолчанию (`stupenkov/...`).

#### Scenario: Wrong default namespace is not used
- **WHEN** выполняется sync description
- **THEN** обновляется именно `stupean/terraform-yc-bootstrap`
- **AND** не предполагается совпадение `github.repository` с именем образа на Hub

### Requirement: Credentials reuse Docker Hub publish secrets
Синхронизация SHALL использовать те же Docker Hub credentials, что и публикация образа (repository secrets), без отдельного обязательного secret только для description — кроме случая, когда мейнтейнер документирует необходимость расширенного scope токена.

#### Scenario: Sync uses configured Hub secrets
- **WHEN** secrets публикации образа заданы и токен имеет достаточный scope для Hub description API
- **THEN** sync description аутентифицируется успешно
- **AND** fork PR не получают доступ к этим secrets для записи на Hub
