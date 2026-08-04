## ADDED Requirements

### Requirement: Description sync follows successful image push
После успешного push образа `stupean/terraform-yc-bootstrap` в Docker Hub (релизный publish или documented republish) система SHALL инициировать обновление Hub repository description из git README. Сбой обновления описания SHALL NOT отменять уже выполненный push образа; ошибка MUST быть видима в CI как отдельный failed step/job.

#### Scenario: Publish succeeds even if description sync fails later
- **WHEN** image push в Docker Hub завершился успешно
- **AND** последующий шаг sync description завершается с ошибкой
- **THEN** теги образа на Hub остаются опубликованными
- **AND** workflow/job отражает failure на шаге description sync
