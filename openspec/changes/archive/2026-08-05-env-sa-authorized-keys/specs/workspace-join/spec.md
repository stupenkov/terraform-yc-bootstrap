## ADDED Requirements

### Requirement: Join audience is bootstrap operators
Workspace join/attach SHALL быть предназначен для peer-операторов landing zone (вторая машина DevOps, коллега по bootstrap root), которым нужен доступ к remote bootstrap state. App-разработчики каталогов окружений (`prod` / `stage` / `dev`) SHALL NOT рассматриваться как целевая аудитория join: им не требуется доступ к bootstrap state bucket.

#### Scenario: Documentation states operator audience
- **WHEN** оператор читает documented join/bootstrap attach path
- **THEN** документация указывает, что join подключает к bootstrap remote state
- **AND** указывает, что app-разработчики окружений не должны использовать join и не должны получать доступ к bootstrap state bucket

#### Scenario: Join mechanics unchanged for operators
- **WHEN** peer-оператор выполняет join с `YC_TOKEN`
- **THEN** happy path (discovery, backend files, mint или reuse AWS keys для SA `tfstate`, `terraform init`) сохраняется
- **AND** join SHALL NOT выдавать authorized key JSON env SA как часть attach
