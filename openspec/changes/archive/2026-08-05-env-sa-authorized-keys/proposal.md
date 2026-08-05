## Why

Service accounts `terraform-prod|stage|dev` создаются без credentials: от их имени нельзя запускать env Terraform roots или CI, пока DevOps вручную не выпустит ключи. Нужен штатный путь bootstrap: authorized key JSON для каждого env SA, доступный DevOps через Terraform state (каталог `platform`) без plaintext objects в bucket и без Lockbox.

## What Changes

- При apply создавать Yandex IAM authorized key для каждого SA `terraform-{prod,stage,dev}`.
- Публиковать private key material через sensitive Terraform outputs (и опционально локальные ignored JSON-файлы по аналогии с `.backend-credentials`).
- **Не** записывать authorized key JSON как отдельные objects в state bucket; источник истины для DevOps — remote bootstrap state в `platform`.
- Зафиксировать threat model в README: app-разработчики не используют join к bootstrap state bucket; join — для peer-DevOps / второй машины оператора landing zone.
- Lockbox по-прежнему не используется.

## Capabilities

### New Capabilities

- (нет)

### Modified Capabilities

- `bootstrap-iam`: для per-environment Terraform SA SHALL выпускаться authorized key; material доступен оператору через sensitive outputs и/или локальные ignored файлы.
- `tfstate-backend`: уточнить, что секреты в Terraform state допустимы при модели «доступ к bootstrap state bucket только у DevOps»; запрет на plaintext shared credentials objects в bucket сохраняется.
- `workspace-join`: уточнить аудиторию join/attach — peer-операторы bootstrap, не app-разработчики окружений (без изменения happy-path механики mint AWS keys).

## Impact

- Terraform: `terraform/iam.tf`, `terraform/outputs.tf`, возможно variables для записи локальных key-файлов и `.gitignore`.
- Документация: README (threat model, как достать JSON для CI / env-root).
- State после apply станет содержать private keys env SA; ротация — через Terraform replace key resource.
- Join/CI app-разработчиков не меняется: они по-прежнему не должны получать доступ к bootstrap state bucket.
