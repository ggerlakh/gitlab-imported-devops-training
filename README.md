# devops-training

## Описание инструментов испоьзуемых для выполнения финального задания

Для выполнения задания были использованы следющие инструменты:
* Terraform для автоматического создания/удаления инфраструктуры в Яндекс облаке. Используемая конфигурация terraform описана в директории `Terraform`:
    * файл main.tf - основной конфигурацинный файл, в котором описывается вся создаваемая инфраструктура в Яндекс облаке.
    * файл vars.tf который используется в main.tf содержащий переменые которые были проброшены в terraform из env репозитория.
    * файл .terraformrc для установки terraform-провайдера от Яндекса.
    * файлы cloud-config.yml и cloud-config-db.yml иницаилизипующие пользователей на виртуальных машинах для приложения и базы данных соответственно
* Ansible для автоматического развертывания приложения и окружения для него на виртуальные машины.
* Gitlab CI для автоматизации процесса управления инфраструктурой и развертывания приложения на виртуальные машины.
<br />
Решение реализовывалось на платформе Gitlab с пробным периодом до 29 декабря, без возможности оькрыть публичный доступ (только по приглашению), поэтому весь исходный код решения был мигрирован в этот публичный Github репозиторий. 
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/45134753-d659-47dd-aee1-400e028f942a"><br />



## Краткое описание решения

В решении использовалась соедующая инфраструктура: 3 виртуальные машины (2 для приложения и одна для БД) и один L3-сетевой балансировщик для балансирования нагрузки на два инстанса приложения. <br />
На каждую виртуальную машину для приложения кроме самого приложения и его окружения был также развернут кэшируюший reverse-proxy в виде nginx.<br />
Деплой приложения и деплой nginx описан через ansible в соответсвующих ansible-ролях `bingo_start` и `nginx`, которые находятся по пути `ansible/roles`. Также в этой же директироии содержатся соответствующие им плейбуки `ansible/deploy-playbook.yml` и `nginx-playbook.yml` в которых используются данные роли и запускается деплой. Само приложение запускалось на виртуальных машинах через systemd.service unit, конфигурация которого описана в `ansbile/roles/bingo-start/files/app/bingo.service`<br />
Для третей виртуальной машины с БД руками (из-за недостатка времени) был развернут PostgreSQL, где была проинициализированана необходимая база данных для приложения. Также в ней были созданы B-Tree индексы на колонки Sessions.id, Customers.id и Movies.id для оптимизации большого количества запросов с фильтрацией по ним.<br /><br />
В файле .gitlab-ci.yml описана небольшая конфигурация ci/cd процесса, который состоял из 4 этапов:
1. `lint` с соответсвующими джобами `lint-terraform` и `lint-ansible`, которые проверку конфигурационных файлов для Terraform и Ansible при создании MR, если таковые были изменены
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/2911aeea-2566-411a-83b7-a485ff578512"><br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/fe1dc202-6e19-47b7-8fe5-4d19c8e65d69">
2. `create-infra` для автоматичекого создания необходимой инфраструктуры в ЯО через Terraform.<br />
На этой стадии при слитии MR в main и наличии изменений в конфигурации Terraform, автоматически запускалась джоба `terraform-plan`, которая после инициализации terraform-провайдера проводила валидацию и планирования конфигурации Terraform.
Также на этой стадии при слитии MR в main и наличии изменений в конфигурации Terraform создавалась еще одна джоба `terraform-apply` ,которая запускается в ручном режиме и после инициализации terraform-провайдера создает инфраструктуру для  из описанной ранее конфигурации.<br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/df4cabe2-ea65-47ea-99d7-9e8ee5aeb064"><br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/85c4501d-baf1-401b-ad40-34bdbc285b80">
3. `destory-infra` для автоматического удаления созданной инфрастурктуры из предыдущей стадии. Удаление происходит в соответсвующей джобе `terraform-destory` и зависит от файла состояния терраформа, который передается из предыдущей стадии. Запускается в ручном режиме.
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/c02f05db-b573-47e1-87ec-7b0c5dcf4302">
4. `deploy` для автоматичекого развертывания приложения на несколько хостов через Ansible, который содержит джобы `bingo-deploy` и `nginx-deploy`, запускаемые также в ручном режиме, для развертывания приложения и кэширующего reverse-proxy nginx. Данные джобы запускают соответствующие им ansible-плейбуки `ansible/deploy-playbook.yml` и `ansible/nginx-playbook.yml`, которые в свою очередь используют ранее упомянутые роли `bingo-start` и `nginx`, соответственно.<br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/dcb64827-a83d-4ab7-b482-14b7689b1e0a"><br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/c63bf16d-e1dd-474f-9091-f5cf557c7d67"><br />
<img width="1470" alt="image" src="https://github.com/ggerlakh/gitlab-imported-devops-training/assets/79301760/077c12e4-133f-456c-a311-8dc12c83852c">





