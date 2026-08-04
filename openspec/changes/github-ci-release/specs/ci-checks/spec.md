## Purpose

Автоматические проверки качества на каждый pull request и push в `main`, без облачных credentials и без публикации артефактов в registry.

## ADDED Requirements

### Requirement: CI runs on pull requests and main pushes
Система SHALL запускать набор проверок качества при открытии/обновлении pull request в репозиторий и при push в ветку `main`.

#### Scenario: Checks on pull request
- **WHEN** открывается или обновляется pull request против `main`
- **THEN** CI выполняет полный набор проверок из этого capability
- **AND** результат видим как status check на PR

#### Scenario: Checks on owner push to main
- **WHEN** владелец пушит коммит напрямую в `main`
- **THEN** CI выполняет тот же набор проверок
- **AND** отсутствие зелёных checks на момент push не блокирует сам git push (gate для внешних — через PR)

### Requirement: Terraform formatting and validation
CI SHALL проверять форматирование Terraform (`fmt -check`) и синтаксическую/схемную валидность модуля (`init -backend=false` + `validate`) без доступа к Yandex Cloud credentials и без remote backend.

#### Scenario: Invalid HCL fails the job
- **WHEN** в `terraform/` есть синтаксическая ошибка или нарушен `fmt`
- **THEN** соответствующий CI job завершается с ошибкой
- **AND** merge/релиз не опираются на «успех» этого job

#### Scenario: Validate without cloud credentials
- **WHEN** CI выполняет `terraform validate` для модуля
- **THEN** не требуются `YC_TOKEN`, org/billing secrets или доступ к Object Storage

### Requirement: Shell and Dockerfile static checks
CI SHALL выполнять статический анализ orchestration-скриптов и Dockerfile (как минимум shellcheck для entrypoint/scripts и hadolint для Dockerfile).

#### Scenario: Shell script lint
- **WHEN** в `scripts/` или `docker/entrypoint.sh` есть нарушение правил shellcheck уровня error
- **THEN** CI job завершается с ошибкой

#### Scenario: Dockerfile lint
- **WHEN** Dockerfile нарушает правила hadolint уровня error (в рамках принятого в репо набора)
- **THEN** CI job завершается с ошибкой

### Requirement: Image builds without registry push
CI SHALL собирать Docker-образ из корневого Dockerfile и выполнять минимальный smoke (entrypoint help или эквивалент), не пуша образ в Docker Hub и не используя Docker Hub publish credentials.

#### Scenario: Build succeeds on PR from fork
- **WHEN** CI запускается для pull request из fork
- **THEN** образ успешно собирается (при корректном Dockerfile)
- **AND** secrets публикации registry недоступны этому запуску
- **AND** в Docker Hub ничего не публикуется

#### Scenario: Smoke after build
- **WHEN** образ собран в CI
- **THEN** контейнер запускается с documented help/usage командой и завершается успешно (exit 0)

### Requirement: No cloud apply in default CI
CI по умолчанию SHALL NOT выполнять `terraform apply`, bootstrap/join против реальной организации Yandex Cloud или иные e2e, требующие org/billing credentials.

#### Scenario: Default pipeline has no YC apply
- **WHEN** выполняется стандартный workflow checks на PR или push в `main`
- **THEN** в jobs нет шагов apply/bootstrap к живой организации
- **AND** не требуются secrets организации Yandex Cloud
