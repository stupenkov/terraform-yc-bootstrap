## 1. Repo layout

- [x] 1.1 Перенести root module: все `*.tf` и `backend.tf.in` → `terraform/`
- [x] 1.2 Перенести справочные файлы: `backend.tf.example`, `terraform.tfvars.example` → `examples/`
- [x] 1.3 Создать `docker/` (заготовка под entrypoint); обновить `.gitignore` под пути `terraform/` (state, `.terraform/`, generated backend files)
- [x] 1.4 Обновить `docker-compose.yml`: `working_dir` → `/app/terraform`, entrypoint → `/app/scripts/bootstrap.sh` и `/app/scripts/join.sh`
- [x] 1.5 Поправить скрипты (`scripts/**`) под новый cwd / пути к `backend.tf.in` и артефактам

## 2. Image layout

- [x] 2.1 Добавить `Dockerfile`: `FROM` pinned `stupean/yandex-terraform@sha256:…`, `COPY terraform/` → `/module`, `COPY scripts/` → `/module/scripts`
- [x] 2.2 Добавить `docker/entrypoint.sh`: команды `bootstrap` / `join` → скрипты; иначе `terraform "$@"`; нормализовать `WORK_DIR` (`/work`) vs `/module`
- [x] 2.3 Адаптировать sync/copy так, чтобы writable артефакты писались в `/work`, а `.tf` читались из `/module` или sync в `/work`
- [x] 2.4 Добавить `.dockerignore` (исключить `.env`, state, `.terraform`, credentials, `openspec/`, `.cursor/`, лишнее)

## 3. Dual path compatibility

- [x] 3.1 Проверить developer-путь: `docker compose run --rm bootstrap` / `join` / `tf` на checkout с новой раскладкой
- [x] 3.2 Убедиться, что `.env.example` остаётся в корне и подхватывается Compose `env_file`

## 4. Документация и pin

- [x] 4.1 Обновить README: primary = `docker run`; структура каталогов; Compose для разработки (`terraform/`)
- [x] 4.2 Зафиксировать имя образа и pin (tag/digest); кратко `docker build` / ручной publish
- [x] 4.3 Обновить комментарии `.env.example` под `docker run --env-file`, если нужно

## 5. Проверка

- [x] 5.1 Локально собрать образ и прогнать `bootstrap`/`join` (или dry-run) без clone
- [x] 5.2 Прогнать developer Compose на checkout
- [x] 5.3 Отметить tasks выполненными после проверки
