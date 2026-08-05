## ADDED Requirements

### Requirement: Operator secrets may reside in Terraform state
Bootstrap MAY хранить operator-facing secret material (включая authorized key private keys env SA и static keys SA `tfstate`) внутри Terraform state, размещённого в state bucket каталога `platform`. Это SHALL NOT считаться нарушением запрета на plaintext shared credentials objects: state — единственный допустимый remote store секретов bootstrap без Lockbox при модели доступа «только DevOps / peer-операторы landing zone».

#### Scenario: Secrets in state are expected
- **WHEN** apply создаёт sensitive credentials (static keys или authorized keys)
- **THEN** private material присутствует в Terraform state после migrate в Object Storage
- **AND** оператор MAY извлекать его через sensitive outputs или `terraform state` / `terraform output`
- **AND** bootstrap SHALL NOT дублировать тот же material отдельным credentials object в bucket для «скачать секрет из S3»

#### Scenario: Open credentials objects remain forbidden
- **WHEN** нужны shared credentials для нескольких машин
- **THEN** система по-прежнему SHALL NOT класть secret keys в открытый plaintext object рядом с `workspace.json`
- **AND** новый оператор landing zone получает AWS keys локально (env / mint), а env SA JSON — от DevOps через output/state или handoff вне bucket
