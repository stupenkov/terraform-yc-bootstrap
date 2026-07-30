## 1. Workspace meta publish

- [x] 1.1 Зафиксировать формат и object key meta (`bootstrap/workspace.json`: cloud_id, folder_ids, bucket, state_key, tfstate_service_account_id, schema_version)
- [x] 1.2 В `scripts/bootstrap.sh` после успешного migrate загрузить meta в state bucket (AWS keys после migrate); без secret keys в JSON
- [x] 1.3 Идемпотентный overwrite meta; путь дописать meta для workspace, созданных до этой фичи

## 2. Discovery и attach

- [x] 2.1 Реализовать discovery-first: YC API под `YC_TOKEN` ищет workspace с meta (ровно один → ok; 0/много → ошибка или `TFSTATE_BUCKET`)
- [x] 2.2 Скачать meta (предпочтительно IAM/YC storage API без AWS keys), записать `backend.tf` + `backend.hcl`
- [x] 2.3 AWS keys без Lockbox: env `AWS_*` или mint static key для SA из meta; `.backend-credentials`
- [x] 2.4 `terraform init -backend-config=backend.hcl` + smoke (`output` или `plan` без apply по умолчанию)

## 3. Compose: smart bootstrap + join

- [x] 3.1 Вынести общий attach-path; сервис `join` = только attach (никогда create)
- [x] 3.2 Smart `bootstrap`: нет remote → discovery → attach | create (0 кандидатов + org/billing) | fail (много без `TFSTATE_BUCKET`)
- [x] 3.3 Проверить tools в образе (`yc` / REST); выбрать transport для discovery, get object, mint key

## 4. Документация

- [x] 4.1 `.env.example`: happy path Dev B = `YC_TOKEN`; `TFSTATE_BUCKET` как disambiguation; без Lockbox
- [x] 4.2 README: Dev A create; Dev B `bootstrap` (smart) или `join`; когда нужен `TFSTATE_BUCKET`
- [x] 4.3 Документировать IAM права (list/get + mint key) и fallback `AWS_*`
