## MODIFIED Requirements

### Requirement: Bootstrap image is versioned and pinned in docs
Документация и примеры запуска SHALL ссылаться на образ с явным version tag или digest (не плавающий `latest` как единственный рекомендуемый pin). Версия запечённого модуля SHALL соответствовать релизу/тегу образа, публикуемому автоматизированным релизным процессом репозитория (Release PR → git tag / GitHub Release → Docker Hub). README SHALL указывать, где взять актуальный pin (GitHub Releases) и как обновить его при новой версии модуля.

#### Scenario: README pins image reference
- **WHEN** оператор следует happy path в README для `docker run`
- **THEN** пример использует image reference с явным version tag или digest
- **AND** README указывает, что актуальные tags/digest публикуются в GitHub Releases
- **AND** README указывает, как обновить pin при обновлении модуля

#### Scenario: Image tag matches module release
- **WHEN** опубликован GitHub Release `vX.Y.Z` и соответствующий образ в Docker Hub
- **THEN** запечённый в образе модуль соответствует исходному дереву этого релизного тега
- **AND** потребители могут сопоставить версию модуля с version tag образа
