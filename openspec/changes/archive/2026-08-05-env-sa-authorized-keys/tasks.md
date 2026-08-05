## 1. Terraform: authorized keys

- [x] 1.1 Добавить `yandex_iam_service_account_key` с `for_each` по `yandex_iam_service_account.terraform_env` в `terraform/iam.tf`
- [x] 1.2 Добавить variable `write_env_sa_keys` (и путь/префикс локальных файлов при необходимости) в `terraform/variables.tf`; отразить в `examples/terraform.tfvars.example`
- [x] 1.3 При `write_env_sa_keys` писать `local_sensitive_file` JSON на каждый env (имена под паттерн `*authorized_key*.json` в `.gitignore`)
- [x] 1.4 Добавить sensitive outputs с key material / JSON по env в `terraform/outputs.tf`; обновить `backend_config_hint` или отдельный hint при необходимости
- [x] 1.5 Убедиться, что нет `yandex_storage_object` (или аналога) с key JSON в bucket

## 2. Документация

- [x] 2.1 README: threat model — bootstrap state bucket / Platform для DevOps; join = peer-оператор landing zone; app-разработчики env не join’ятся к bootstrap bucket
- [x] 2.2 README: как извлечь env SA authorized key (`terraform output`, локальные JSON) и использовать с `YC_SERVICE_ACCOUNT_KEY_FILE` / CI
- [x] 2.3 При необходимости уточнить `.env.example` / examples под новые variables

## 3. Проверка

- [x] 3.1 `terraform validate` / plan на модуле (compose или native) — create keys без unexpected destroys
- [x] 3.2 `openspec validate env-sa-authorized-keys --strict` (или актуальный validate для change)
