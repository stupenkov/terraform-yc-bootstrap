## Context

См. proposal.md — Why. Сейчас `terraform/iam.tf` создаёт SA `terraform-{prod,stage,dev}` с `editor` на свой folder, без `yandex_iam_service_account_key`. Static keys есть только у SA `tfstate` (S3 backend + `.backend-credentials`). Lockbox и plaintext credentials objects в bucket запрещены спеками. Threat model оператора: bootstrap state bucket в `platform` — только DevOps / peer landing-zone; app-разработчики env roots bucket не трогают.

## Goals / Non-Goals

**Goals:**
- Authorized key на каждый env Terraform SA при apply.
- Sensitive outputs (+ опционально локальные JSON) как DX для DevOps → CI / `YC_SERVICE_ACCOUNT_KEY_FILE`.
- Явно задокументировать аудиторию join vs env-разработчиков.

**Non-Goals:**
- Отдельные S3 objects с JSON ключами.
- Lockbox / внешний secret manager.
- Authorized keys для SA `bootstrap` или замена static keys SA `tfstate`.
- Impersonation / Workload Identity federation (возможный follow-up).
- Изменение механики mint AWS keys на join.

## Decisions

### 1. Ресурс ключа
- **Choice:** `yandex_iam_service_account_key` с `for_each` по тем же env SA, что `terraform_env`.
- **Why:** Нативный Terraform resource; private key попадает в state автоматически — совпадает с желаемым «хранить в tfstate Platform».
- **Alternatives:** Ручной `yc iam key create` вне модуля; только impersonation без ключей.

### 2. Формат выдачи оператору
- **Choice:** Sensitive outputs (map по env: JSON или поля `id` / `key` / `service_account_id` в форме, достаточной для key file). Опционально `local_sensitive_file` per env при variable вроде `write_env_sa_keys` (default согласован с `write_backend_credentials` или отдельный флаг — предпочтительно отдельный, default `true` в примерах для DevOps DX).
- **Why:** Output всегда доступен из state; local file удобен для Docker `--env-file` / mount JSON без ручного copy-paste.
- **Alternatives:** Только outputs; только local files; object в bucket (отклонено).

### 3. Не дублировать в Object Storage
- **Choice:** Никаких `yandex_storage_object` с key JSON.
- **Why:** Тот же ACL, что у bucket; нарушает дух «no credentials objects»; state уже хранит секрет.
- **Alternatives:** «Зашифрованный» object с SSE bucket key — не даёт изоляции от читателя bucket.

### 4. Scope SA
- **Choice:** Только `terraform-{prod,stage,dev}`. Не `bootstrap`, не `tfstate`.
- **Why:** Env roots нуждаются в Yandex provider auth; tfstate уже имеет static keys; bootstrap SA — для структурных задач, ключ можно выпустить отдельно при необходимости.
- **Alternatives:** Ключи на все SA сразу (лишний blast radius в state).

### 5. Документация threat model
- **Choice:** README: Platform/bootstrap state = DevOps; join = peer-оператор; app-dev получают env key через handoff DevOps (output), не через join.
- **Why:** Снимает путаницу «Dev B» в quick start с app-разработчиком.
- **Alternatives:** Ломать join для всех кроме одного пользователя (не нужно при заявленной модели).

### 6. Gitignore
- **Choice:** Переиспользовать / уточнить уже существующий паттерн `*authorized_key*.json`; имена локальных файлов согласовать с паттерном (например `terraform/terraform-prod-authorized-key.json`).
- **Why:** Паттерн уже в `.gitignore`.

## Risks / Trade-offs

- [Private keys в remote state] → Принято при DevOps-only доступе к bucket; README предупреждает: доступ к state = доступ к env keys.
- [Peer join всё ещё mint’ит AWS keys на тот же bucket] → Peer-DevOps читает state (и ключи). Документировать; не путать с app-dev.
- [Ротация ключа] → `terraform taint` / replace resource; старый key revoke в IAM; обновить CI.
- [Key JSON в CI logs при неосторожном output] → Sensitive outputs; документировать не логировать raw output в pipeline без secret store.
- [Существующие workspace без ключей] → Обычный apply добавит resources; не breaking для уже созданных SA.

## Migration Plan

1. Обновить модуль; `terraform plan` на существующем state покажет create key resources.
2. Apply; извлечь JSON через output / local files; положить в CI secrets для будущих env roots.
3. Rollback: удалить key resources из конфига и apply (revoke keys) — env roots с этими JSON перестанут аутентифицироваться; заранее спланировать замену.

## Open Questions

- Точное имя variable для локальных JSON (`write_env_sa_keys` vs расширить `write_backend_credentials`) — решить при реализации в пользу отдельного флага, чтобы не смешивать AWS backend creds и YC SA JSON.
