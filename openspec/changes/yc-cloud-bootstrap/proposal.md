## Why

Ручная настройка landing zone в Yandex Cloud (каталоги, bucket для state, service accounts) подвержена ошибкам и плохо воспроизводится. В этом репозитории нужен Terraform-bootstrap, который создаёт согласованную структуру облака — каталоги окружений, Object Storage для удалённого Terraform state и IAM-субъекты с наименьшими необходимыми правами — чтобы последующие workload-конфигурации можно было применять безопасно с общим remote backend.

## What Changes

- Добавить Terraform root module, который создаёт облако Yandex Cloud (или подключается к существующему) и каталоги `prod`, `stage`, `dev`, а также отдельный каталог для общих platform-ресурсов (например, `platform`).
- Создать Object Storage bucket в каталоге `platform` для Terraform remote state (S3-compatible backend) с документированным переходом local state → remote state (chicken-and-egg).
- Создать service accounts и IAM role bindings для управления каталогами и доступа к state (bootstrap/admin SA, state-access SA, опционально per-environment Terraform SA).
- Добавить каркас репозитория: конфигурация provider/`versions` по [quickstart Yandex Cloud Terraform](https://yandex.cloud/ru/docs/terraform/quickstart), variables, outputs, `.gitignore` и README с шагами auth и apply.
- Задокументировать **предпочтительный apply** через Docker-образ [`stupean/yandex-terraform`](https://hub.docker.com/repository/docker/stupean/yandex-terraform/general) (`docker pull` / `docker run` с mount проекта в `/app` и credentials `YC_*`); нативный Terraform на хосте остаётся альтернативой.
- **Non-goals**: application workloads (VM, сети, k8s), CI/CD pipelines, YDB state locking (можно отметить как follow-up), настройка organization/federation сверх необходимого для создания облака, сборка и публикация Docker-образа в этом репозитории.

## Capabilities

### New Capabilities
- `cloud-structure`: создание/управление облаком и каталогами окружений (`prod`, `stage`, `dev`) плюс выделенный каталог `platform` для общих ресурсов.
- `tfstate-backend`: provision Object Storage (S3) для Terraform remote state и outputs с параметрами backend.
- `bootstrap-iam`: создание service accounts и назначение ролей для bootstrap apply, доступа к state и управления окружениями.

### Modified Capabilities
- (нет — greenfield-репозиторий)

## Impact

- Новый Terraform-код и документация в `terraform-yc-bootstrap` (сейчас пусто, кроме OpenSpec-инструментов).
- Зависимости: provider `yandex-cloud/yandex`, существующие organization и billing account, credentials оператора с правом создавать облако (или каталоги в существующем).
- Предпочтительный runtime оператора: Docker-образ `stupean/yandex-terraform` (опционально при host-installed Terraform + provider mirror).
- Outputs (folder IDs, имя bucket, SA IDs, фрагмент backend) станут входами для будущих Terraform roots окружений.
- Первый apply использует local state; после появления bucket state мигрирует в S3 backend по руководству Yandex Cloud по remote state.
