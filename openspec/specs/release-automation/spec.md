# release-automation Specification

## Purpose

Осознанный релизный цикл: SemVer и CHANGELOG готовятся в Release PR; tag и GitHub Release появляются только после явного merge этого PR.

## Requirements

### Requirement: Release PR proposes version and changelog
Система SHALL на основе Conventional Commits на `main` поддерживать Release PR, который предлагает следующую SemVer-версию и обновлённый CHANGELOG. Публикация релиза SHALL происходить только после merge этого PR, а не на каждый `feat`/`fix` push в `main`.

#### Scenario: Commits accumulate without publishing
- **WHEN** в `main` появляются коммиты `feat:` или `fix:` и Release PR ещё не смёржен
- **THEN** git tag релиза и GitHub Release ещё не создаются
- **AND** Release PR (существующий или новый) отражает накопленные изменения и предлагаемую версию

#### Scenario: Merge of Release PR publishes
- **WHEN** мейнтейнер мержит Release PR в `main`
- **THEN** создаётся git tag вида `vX.Y.Z`
- **AND** создаётся GitHub Release с notes, согласованными с CHANGELOG

### Requirement: SemVer from Conventional Commits
Версия SHALL вычисляться по Conventional Commits: `fix` → patch, `feat` → minor, breaking (`!` или `BREAKING CHANGE`) → major. Коммиты типов `docs`, `chore`, `ci`, `test`, `refactor` (без breaking) SHALL NOT сами по себе поднимать версию.

#### Scenario: Feature bump
- **WHEN** с последнего релиза на `main` есть `feat:` и нет breaking
- **THEN** Release PR предлагает minor-бампа (например `1.2.0` → `1.3.0`)

#### Scenario: Non-release commits only
- **WHEN** с последнего релиза на `main` только `chore:` / `docs:` / `ci:` без breaking
- **THEN** система не обязана открывать Release PR с новой версией (или PR не предлагает bump)

### Requirement: Changelog is maintained in repository
Репозиторий SHALL содержать CHANGELOG, обновляемый релизным процессом; содержимое релизных notes SHALL соответствовать изменениям, отражённым в CHANGELOG для этой версии.

#### Scenario: Changelog updated in Release PR
- **WHEN** открыт или обновлён Release PR
- **THEN** в diff PR есть изменения CHANGELOG для предлагаемой версии
- **AND** после merge файл CHANGELOG в `main` содержит секцию этой версии

### Requirement: Collaboration model for trunk and forks
Внешние контрибьюторы SHALL вносить изменения через fork и pull request. Владельцы MAY пушить напрямую в `main`. Релизный бот MAY создавать коммиты/PR и теги, необходимые для release-автоматизации.

#### Scenario: External contribution via fork
- **WHEN** сторонний разработчик предлагает изменение
- **THEN** путь — fork + PR в upstream `main`
- **AND** прямой push в upstream `main` для него недоступен

#### Scenario: Owner direct push
- **WHEN** владелец пушит в `main` с Conventional Commit
- **THEN** изменение попадает в trunk без обязательного PR
- **AND** учитывается релизной автоматизацией при следующем Release PR
