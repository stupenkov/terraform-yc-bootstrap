# bootstrap-image Specification

## Purpose

Публикуемый Docker-образ с запечённым Terraform bootstrap-модулем и orchestration, чтобы потребитель landing zone мог запускать bootstrap/join одной командой `docker run` без `git clone`.

## Requirements

### Requirement: Baked-in module image without clone
Система SHALL предоставлять Docker-образ, в котором находятся Terraform-конфигурация landing zone (из каталога `terraform/` репозитория), шаблоны backend и orchestration-скрипты (`bootstrap` / `join`), так чтобы оператор мог выполнить bootstrap или join без клонирования git-репозитория на хост.

#### Scenario: Bootstrap via docker run without repository checkout
- **WHEN** оператор имеет Docker Engine и валидный `YC_TOKEN` (плюс org/billing или `cloud_id` для create)
- **AND** выполняет `docker run --rm` с образом bootstrap и командой `bootstrap`, передавая credentials через `-e` или `--env-file`
- **THEN** контейнер выполняет тот же create-or-attach workflow, что и Compose-путь
- **AND** на хосте не требуется наличие checkout репозитория с `.tf` файлами

#### Scenario: Join via docker run without repository checkout
- **WHEN** оператор выполняет `docker run --rm` с образом и командой `join` при валидном `YC_TOKEN`
- **THEN** выполняется attach-only к существующему workspace (discovery / disambiguation)
- **AND** команда не создаёт новое облако

### Requirement: Image build sources organized directories
Образ SHALL собираться из организованного дерева репозитория: Terraform root из `terraform/`, orchestration из `scripts/`, entrypoint из `docker/`; справочные `examples/` не обязаны входить в runtime-образ.

#### Scenario: Dockerfile copies terraform and scripts
- **WHEN** выполняется `docker build` из корня репозитория
- **THEN** в образ попадают содержимое `terraform/` и `scripts/` (и entrypoint из `docker/`)
- **AND** секреты (`.env`, state, credentials) не копируются благодаря `.dockerignore`

### Requirement: Image commands cover bootstrap join and terraform
Образ SHALL предоставлять entrypoint (или эквивалентный CLI-обёртку), принимающий как минимум команды `bootstrap`, `join` и прямой вызов Terraform (`plan` / `apply` / `output` / `init` и т.п.) против запечённого модуля.

#### Scenario: Day-two plan through image
- **WHEN** remote backend уже доступен (через ранее записанный workspace cache на volume или через повторный attach в том же запуске)
- **AND** оператор запускает образ с командой Terraform `plan` (или documented day-two эквивалентом)
- **THEN** plan выполняется против remote state без установки Terraform на хост

### Requirement: Optional workspace volume for local artifacts
Образ SHALL поддерживать опциональный bind-mount рабочей директории хоста для записи локальных артефактов (`backend.tf`, `backend.hcl`, `.backend-credentials`, `.terraform/`, `.workspace.env`). Без mount запуск MAY быть ephemeral: артефакты не сохраняются на хост, а последующий запуск снова выполняет discovery/attach при необходимости.

#### Scenario: Persist backend hints on host volume
- **WHEN** оператор монтирует пустую (или существующую) рабочую директорию в documented mount path образа
- **AND** успешно завершает `bootstrap` или `join`
- **THEN** на смонтированном volume появляются необходимые локальные файлы для последующего day-two без полного повторного discovery (если credentials ещё валидны)

#### Scenario: Ephemeral run without volume
- **WHEN** оператор запускает `bootstrap`/`join` без bind-mount рабочей директории
- **THEN** операция всё равно может завершиться успешно при валидных credentials и однозначном workspace
- **AND** локальные backend/credentials файлы не обязаны появляться на хосте

### Requirement: Bootstrap image is versioned and pinned in docs
Документация и примеры запуска SHALL ссылаться на образ с явным version tag или digest (не плавающий `latest` как единственный рекомендуемый pin). Версия запечённого модуля SHALL соответствовать релизу/тегу образа, публикуемому автоматизированным релизным процессом репозитория (Release PR → git tag / GitHub Release → Docker Hub). README SHALL указывать, где взять актуальный pin (GitHub Releases) и как обновить его при новой версии модуля.

#### Scenario: README pins image reference
- **WHEN** оператор следует happy path в README для `docker run`
- **THEN** пример использует image reference с явным version tag или digest
- **AND** README указывает, что актуальные tags/digest публикуются в GitHub Releases
- **AND** README указывает, как обновить pin при обновлении модуля

#### Scenario: Image tag matches module release
- **WHEN** опубликован GitHub Release `vX.Y.Z` и соответствующий образ в Docker Hub
- **THEN** запечённый в образе модуль соответствует исходному дереву этого релизного тега
- **AND** потребители могут сопоставить версию модуля с version tag образа
