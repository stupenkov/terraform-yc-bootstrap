# docker-publish Specification

## Purpose

Публикация bootstrap Docker-образа в Docker Hub строго по релизному тегу, с immutable version tag и digest для pin потребителями.

## Requirements

### Requirement: Publish image only on release tag
Система SHALL собирать и пушить образ `stupean/terraform-yc-bootstrap` в Docker Hub только при появлении релизного git tag `vX.Y.Z` (или эквивалентного GitHub Release), а не на каждый push в `main` и не из pull request (включая fork).

#### Scenario: Tag triggers publish
- **WHEN** создан релизный tag `vX.Y.Z` после merge Release PR
- **THEN** CI собирает образ из того же коммита тега
- **AND** пушит его в Docker Hub под соответствующими tags

#### Scenario: Main push does not publish
- **WHEN** выполняется push в `main` без создания релизного tag
- **THEN** образ в Docker Hub не публикуется этим событием

#### Scenario: Fork PR cannot publish
- **WHEN** CI выполняется для pull request из fork
- **THEN** secrets Docker Hub недоступны
- **AND** push в registry не выполняется

### Requirement: Immutable version tag and latest convenience tag
Опубликованный релиз SHALL включать immutable tag, соответствующий версии релиза (например `1.2.3` или `v1.2.3` — единый выбранный формат в design), и MAY обновлять floating tag `latest`. Документация для потребителей SHALL рекомендовать pin по version tag или digest, а не только `latest`.

#### Scenario: Version tag is immutable reference
- **WHEN** релиз `v1.2.3` успешно опубликован
- **THEN** в Docker Hub существует tag образа, однозначно соответствующий этой версии
- **AND** повторная публикация другой версии не перезаписывает этот version tag

#### Scenario: Latest updated on release
- **WHEN** новый релиз успешно опушен в Docker Hub
- **THEN** tag `latest` указывает на этот релиз (если политика репо включает обновление `latest`)

### Requirement: Digest available for pinning
После успешной публикации система SHALL делать digest образа доступным потребителю через GitHub Release notes (и/или документированный способ), чтобы можно было pin'ить `@sha256:…`.

#### Scenario: Release notes include digest
- **WHEN** Docker-образ успешно запушен для релиза `vX.Y.Z`
- **THEN** GitHub Release (или связанная документация релиза) содержит digest опубликованного образа
- **AND** оператор может использовать `stupean/terraform-yc-bootstrap@sha256:…` как pin

### Requirement: Single-arch linux/amd64 for initial publish
Первая версия пайплайна публикации SHALL собирать как минимум `linux/amd64`. Multi-arch (arm64) MAY быть добавлен позже и не требуется этим capability.

#### Scenario: Published image runs on amd64
- **WHEN** потребитель на linux/amd64 выполняет `docker pull` version tag релиза
- **THEN** образ успешно загружается и запускается
