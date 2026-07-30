## ADDED Requirements

### Requirement: Workspace meta object is published after migrate
После успешной миграции bootstrap state в Object Storage система SHALL записать в тот же state bucket несекретный workspace meta-object по задокументированному object key. Meta SHALL включать как минимум: cloud_id, folder_ids, bucket name, bootstrap state key, id service account tfstate. Meta MUST NOT содержать static secret keys, IAM tokens или содержимое `.backend-credentials`.

#### Scenario: Meta written after successful migrate
- **WHEN** automated bootstrap успешно завершает `init -migrate-state` в state bucket
- **THEN** в bucket существует meta-object с cloud_id, folder_ids, bucket, state key и tfstate SA id
- **AND** object не содержит AWS secret access key или YC token

#### Scenario: Meta is readable for join
- **WHEN** оператор или join/attach-команда читает meta-object с валидными правами на bucket
- **THEN** данных достаточно, чтобы сформировать `backend.hcl` и знать, для какого SA выпускать static keys

#### Scenario: Meta supports IAM-based discovery
- **WHEN** attach выполняет discovery под `YC_TOKEN` без заранее известных AWS keys
- **THEN** наличие meta-object в bucket является критерием «это bootstrap workspace»
- **AND** содержимое meta читается способом, не требующим Lockbox (YC Object Storage API / эквивалент с IAM token или последующий S3 get после mint keys)

### Requirement: No secret material in open bucket objects for credentials sharing
Bootstrap и связанные automation paths SHALL NOT использовать Yandex Lockbox и SHALL NOT хранить state-access secret keys в публично читаемых (для всех с list/get на bucket) «credentials» objects как замену локальному ignored файлу. Локальный `.backend-credentials` остаётся operator-facing only.

#### Scenario: Credentials stay local or freshly minted
- **WHEN** нужны AWS-совместимые keys для S3 backend на новой машине
- **THEN** они берутся из локального env/файла или создаются заново для SA tfstate
- **AND** не восстанавливаются из открытого plaintext object, предназначенного как «shared secrets store» в том же bucket
