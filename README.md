# Настраиваем сервер Linux (Ubuntu/Debian) под ТГ-бота вебхук (FastAPI + Uvicorn).
**Стэк для бота:** Postgres, Redis, Nats и др..  
**Стэк на сервере:** Git, Docker (docker-compose), Nginx, Certbot, Pyenv, Cron  
Cron и Pyenv были мной добавлены отдельно, а не в докере, так как не разобрался с корректным запуском крона в докере, при котором можно смотреть логи крона. Если вы знаете, как корректно запускать крон в докере, буду признателен за комментарии. (https://t.me/EVGENIY_JEM)

  Я понимаю, что в эпоху GPT многие инструкции становятся не нужны, но чтобы сэкономить время, в первую очередь самому себе, я набросал мануал, который выполнил на последнем проекте.  
  ВАЖНОЕ ЗАМЕЧАНИЕ! Я не считаю себя профессионалом и не считаю, что мой способ самый лучший и корректный. Данный мануал - это лишь личный опыт, а я не претендую на истину в последней инстанции.

## 1.	Обновляем системные пакеты:
    sudo apt update
    sudo apt dist-upgrade
    sudo apt upgrade

## 2.	Устанавливаем Git, Docker, и Nginx, и другие:
    sudo apt install git docker.io nginx docker-compose
    sudo apt install -y build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev wget curl llvm libncurses5-dev libncursesw5-dev xz-utils tk-dev libffi-dev liblzma-dev python3-openssl
    sudo systemctl enable docker
    sudo systemctl enable nginx

## 3.	Устанавливаем Certbot для работы с SSL:
    sudo apt install certbot python3-certbot-nginx

## 4.	Настройка SSL для Nginx: 
### a.	Запускаем Certbot для настройки SSL:
    sudo certbot -–nginx
### b.	Следуем инструкциям, чтобы настроить SSL для вашего домена. Там не сложно. Ввести почту, Имя своего домена сервера, Согласится, потом Не согласится и готово (последовательность уже не помню, но примерно так).

## 5.	Запускаем Nginx
    sudo systemctl enable nginx
    sudo systemctl start nginx 
    systemctl status nginx
В выводе команды вы должны увидеть что-то вроде Active: active (running)

## 6.	Настройка Nginx:
### a.	Создайте файл конфигурации для вашего сайта в /etc/nginx/sites-available/:
    sudo nano /etc/nginx/sites-available/YOUR_DOMAIN_NAME
### b.	Добавьте следующее содержимое в файл конфигурации:
    server {
      listen 80;
      server_name YOUR_DOMAIN_NAME;
      return 301 https://$host$request_uri;
    }
    
    server {
      listen 443 ssl;
      server_name YOUR_DOMAIN_NAME;
    
      ssl_certificate /etc/letsencrypt/live/YOUR_DOMAIN_NAME/fullchain.pem;
      ssl_certificate_key /etc/letsencrypt/live/YOUR_DOMAIN_NAME/privkey.pem;
      # Дополнительные параметры SSL (опционально)
      ...
    
      location / {
        proxy_pass http://localhost:YOUR_BOT_PORT; # Порт, на котором работает ваш Telegram бот
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      }
    }

Замените YOUR_BOT_PORT на порт, на котором работает ваш Telegram бот (который вы пробросили из Docker-контейнера на хост-машину)
Замените YOUR_DOMAIN_NAME на имя, которое вы использовали при регистрации сертификата ssl, из п.4.
### c.	Создайте символическую ссылку на этот файл в директории sites-enabled
    sudo ln -s /etc/nginx/sites-available/YOUR_DOMAIN_NAME /etc/nginx/sites-enabled/
### d.	Переименовать дефолтные настройки, во избежание конфликта. Либо закомментировать все строки в файле default:
    sudo mv /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.backup
### e.	Проверьте конфигурацию Nginx:
    sudo nginx -t 
Если все в порядке, вы должны увидеть сообщение: `syntax is okay, test is successful`
### f.	Перезапустите Nginx:
    sudo systemctl restart nginx

## 7.	Установка вебхука для Telegram-бота:
### a.	Обычно это делается внутри кода, в файле запуска бота. Задача дать понять Телеграму, что все обновления нужно слать вам на адрес вебхука. Но если вы не делали это в коде, то можно прямо с консоли отправить:
    curl -F "url=https://YOUR_DOMAIN/YOUR_WEBHOOK_PATH" https://api.telegram.org/botYOUR_BOT_TOKEN/setWebhook
### b.	Проверить:
    curl https://api.telegram.org/botYOUR_BOT_TOKEN/getWebhookInfo
В ответ должны быть показаны данные вашего вебхука

## 8.	Для настройки докер контейнера делаем в корневой папке проекта файл Dockerfile:
    # Используем официальный образ Python
    FROM python:3.11.5
    
    # Устанавливаем рабочую директорию в контейнере
    WORKDIR /app
    
    # Копируем зависимости и устанавливаем их
    COPY requirements.txt .
    RUN pip install --upgrade pip setuptools
    RUN pip install -r requirements.txt
    RUN chmod 755 .
    
    # Копируем исходный код в контейнер
    COPY . .
    
    # Указываем команду для запуска приложения
    CMD ["python", "app.py"] # Указываем название вашего главного файла

## 9.	Также там-же делаем файл .dockerignore со следующим содержанием:

    # Игнорируем каталоги с зависимостями и кэшем Python
    __pycache__/
    *.pyc
    *.pyo
    venv/

    # Игнорируем файлы и каталоги Git
    .git/

    # Игнорируем каталог с логами
    logs/

    # Игнорируем временные директории и файлы
    tmp/

    # Осторожно с исключением файлов конфигурации и секретов.
    # Если эти файлы необходимы для запуска вашего приложения, их исключение может привести к сбоям.
    # *.config
    # *.env
    # *.secret

    # Игнорируем директории и файлы, созданные IDE или текстовыми редакторами
    .vscode/
    .idea/

    # Добавьте другие папки и файлы, которые не должны быть включены в ваш Docker-образ

## 10.	Также там-же делаем файл .gitignore следующего содержания:
    
    # Игнорируем каталоги с зависимостями и кэшем Python
    __pycache__/
    *.pyc
    *.pyo
    venv/
    
    # Игнорируем локальные конфигурационные файлы и секреты
    *.config
    *.env
    *.secret
    
    # Игнорируем каталог с логами
    logs/
    
    # Игнорируем каталог с бинарными файлами и дистрибутивами
    dist/
    *.egg-info/
    
    # Игнорируем IDE-специфичные файлы (например, для PyCharm)
    .idea/
    .vscode/
    
    
    # Если есть тестовые данные, которые не должны попадать в репозиторий
    # test_data/
    
    # Добавьте другие папки и файлы, которые не должны быть включены в ваш Git-репозитарий


## 11.	Также там-же делаем файл docker-compose.yml, в котором создаем наши службы, пробрасываем порты, перечисляем зависимости. Этот файл служит основой запуска вашего проекта. 
Мой предыдущий проект имел файл со следующим содержанием: бот, база данных postgres, база данных redis, nats сервер и nats воркер (для взаимодействия с nats сервером)
В 18м пункте смотрите, как собирался контейнер для nats сервера.
    
    version: "3"
    services:
      имя_службы_бота:
        build: .
        container_name: имя_службы_бота
        ports:
          - "8080:8080"
        command: [ "python", "app.py" ] # app.py - Название главного файла проекта
        depends_on:
          - nats-server  # указываем зависимость от NATS сервера
          - redis  # добавляем зависимость от Redis
          - postgres  # добавляем зависимость от PostgreSQL
        restart: always

      nats_worker:
        build: .
        container_name: nats_worker
        command: [ "python", "nats_worker.py" ]
        depends_on:
          - nats_server  # указываем зависимость от NATS сервера
          - redis  # добавляем зависимость от Redis
          - postgres  # добавляем зависимость от PostgreSQL
        restart: always
        
      # Имейте в виду, что в конфиг файле бота в .env или settings.toml, смотря что используете,
      # адрес хоста должен быть не 127.0.0.1, а именем службы из вашего docker-compose: NATS_HOST='nats_server'
      nats_server: # Добавляем NATS сервер как новую службу.
        build:
          context: .
          dockerfile: Dockerfile.nats  # Указываем путь к Dockerfile.nats в котором все настройки и параметры запуска (см. п.18)
        ports:
          - "4222:4222"  # открываем порт для внешних соединений
          - "6222:6222"
          - "8222:8222"  # Для HTTP мониторинга
        volumes:
          - "nats_data:/app/data"  # Папка для хранения данных (в моем случае в папку проекта в папке data)
        # - "nats_logs:/app/logs"  # Папка для логов (не обязательна)
        restart: always
    
      # Имейте в виду, что в конфиг файле бота в .env или settings.toml, смотря что используете,
      # адрес хоста должен быть не 127.0.0.1, а именем службы из вашего docker-compose: REDIS_HOST='redis'
      redis: # добавляем Redis сервер как новую службу
        image: "redis:latest"  # можно указать конкретную версию вместо latest
        ports:
          - "6379:6379"  # открываем порт для внешних соединений
        restart: always
    
      # Имейте в виду, что в конфиг файле бота в .env или settings.toml, смотря что используете,
      # адрес хоста должен быть не 127.0.0.1, а именем службы из вашего docker-compose: POSTGRES_HOST='postgres'
      postgres: # добавляем PostgreSQL сервер как новую службу
        image: "postgres:latest"  # можно указать конкретную версию вместо latest
        volumes:
          - postgres_data:/var/lib/postgresql/data
        environment:
          POSTGRES_DB: ${имя_переменной_из_env_файла}
          POSTGRES_USER: ${имя_переменной_из_env_файла}
          POSTGRES_PASSWORD: ${имя_переменной_из_env_файла}
        ports:
          - "5432:5432"  # открываем порт для внешних соединений
        restart: always
    
    volumes:
      postgres_data:  # объявляем volume для постоянного хранения данных PostgreSQL. Если не указать, то при остановке docker-compose и повторного запуска, ваши файлы пропадут
      nats_data:

## 12.	Я использую Git (GitHub) в качестве репозитария и считаю хорошей привычкой все делать через него. Также это позволяет удобно и быстро разворачивать проекты в новом месте. Для себя избрал самый быстрый и надежный способ – использовать SSH ключ, поэтому моя инструкция ниже. 
### a.	Далее создаем SSH ключ на сервере, если SSH ключ уже присутствует на сервер, то сразу к пункту “c”:
    ssh-keygen -t rsa -b 4096 -C "ваша почта, с которой вы регались на github"
Просто нажимайте "Enter" для всех вопросов, если вы хотите использовать параметры по умолчанию.
### b.	Запуск SSH-агента и добавление вашего ключа:
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_rsa
### c.	Копирование SSH-ключа в буфер обмена. Команда выведет ваш публичный SSH-ключ. Скопируйте его в буфер обмена:
    cat ~/.ssh/id_rsa.pub
### d.	Добавление нового SSH-ключа на GitHub:
Перейдите на GitHub и зайдите в "Settings" (находится в правом верхнем углу).
В меню слева выберите "SSH and GPG keys" -> "New SSH key".
Вставьте скопированный ключ в поле "Key" и дайте ему название.

## 13.	Клонирование репозитория с использованием SSH:
### a.	Перейдите в папку, в которой вы планируете размещать свои проекты. Я обычно создаю папку apps и все проекты клонирую туда:
    mkdir apps
    cd apps
### b.	Запустите команду клонирования проекта, которую можно скопировать с GitHub, нажав зеленую кнопочку code, выбрав SSH:
    git clone git@github.com:ваше_имя_пользователя_github/название_проекта.git
После этого сервер вас спросит, действительно ли доверяется этому ssh ключу, подтвердите и проект будет скопирован к вам на сервер в apps/название_проекта_из_github

## 14.	Обновляемся, собираем и запускаем контейнер, смотрим логи:
### a.	Перейдите в папку с проектом (см п. 13)
    cd apps/название_проекта
### b.	Если вы внесли какие-то изменения в проект и необходимо их применить на сервере (если контейнер уже запущен, то сначала остановить):
    git pull
### c.	Остановить запущенный контейнер:
    docker-compose down
### d.	Собрать и запустить контейнер (с указанными аргументами контейнер пересобирается и работает, если сервер будет перезагружен):
    docker-compose up -d –build
### e.	Если необходимо зайти внутрь запущенного контейнера и провести там какие-то манипуляции: 
    docker exec -it container_id_or_name /bin/bash)
### f.	Если вы хотите видеть логи приложения: 
    docker-compose logs -f имя_контейнера_из_docker-compose.yml


## 15.	Alembic. Если в вашем проекте база данных, то таблицы должны быть размечены прежде, чем все заработает. Вы можете это сделать вручную, зайдя внутрь соответствующего контейнера (службы postgres из файла docker-compose.yml) или если вы используете миграцию от Alembic, то команды для запуска и разметки таблиц бд, не заходя внутрь контейнера:
### a.	Создание новой миграции:
    docker exec -it container_id_or_name alembic revision --autogenerate -m "Initial migration"
### b.	Применение новой миграции:
    docker exec -it container_id_or_name alembic upgrade head
## 16.	Использование Pyenv (не для Docker, а именно на сервере). Pyenv позволяет установить несколько версий Python и переключаться между ними, если нужно. Если бы вопрос с Cron я смог решить в docker-compose, то не стал бы этим заморачиваться:
### a.	Установка pyenv:
    curl https://pyenv.run | bash 
### b.	Добавляем pyenv в $PATH:
    echo 'export PATH="$HOME/.pyenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(pyenv init --path)"' >> ~/.bashrc
    source ~/.bashrc
### c.	Теперь необходимо обновить файлы конфигурации вашей оболочки, чтобы pyenv автоматически загружался при старте. Откройте файл .bashrc в текстовом редакторе:
    nano ~/.bashrc 
### d.	Вставьте следующие строки в конец файла:
    export PYENV_ROOT="$HOME/.pyenv"
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
### f.	Сохраните изменения и закройте редактор. Примените изменения:
    source ~/.bashrc
### g.	Устанавливаем Python:
    pyenv install 3.11.5 
### h.	Устанавливаем его как глобальную версию:
    pyenv global 3.11.5 
### i.	Теперь ваша система должна использовать выбранную версию Python по умолчанию. Вы можете проверить это, запустив:
    python --version 
Эта команда должна показать Python 3.11.x.

## 17.	Использование Cron. Чтобы запускать какой-то файл по расписанию, необходимо, чтобы все библиотеки, используемые в этом файле были установлены в системе (в нашем случае в окружении Pyenv, которое в п.16 мы установили и настроили):
### a.	Переходим в папку с проектом:
    cd путь_до_проекта/название_вашего_проекта
### b.	Устанавливаем все необходимые библиотеки (зависимости):
    pip install -r requirements.txt
### c.	Для дальнейшего использования cron нам необходимо знать в какой директории установлен питон:
    pyenv which python 
### d.	Открываем список заданий cron:
    crontab -e
### e.	Добавляем вниз наше задание:
    */5 * * * * cd /home/ваше_имя_пользователя/ваш_путь/до_папки_проекта && /home/ ваше_имя_пользователя /.pyenv/versions/3.11.5/bin/python имя_запускаемого_файла.py >> /home/ваше_имя_пользователя/ваш_путь/до_папки_с_логами/cron.log 2>&1 

0 0 * * * - это пример, для запуска каждый день в 00:00  
Здесь:  
•	Первый 0 обозначает минуты (0 минут).  
•	Второй 0 обозначает часы (0 часов, или полночь).  
•	Звёздочки обозначают "любое значение" для дней месяца, месяцев и дней недели соответственно.  

## 18.	Для сборки docker контейнера nats сервера создаем в корне вашего проекта файл Dockerfile.nats следующего содержания:  
    # Используем базовый образ Debian
    FROM debian:bullseye-slim
    
    # Устанавливаем необходимые пакеты (wget и tar) - для загрузки и распаковки наших образов
    RUN apt-get update && \
        apt-get install -y wget tar
    
    # Загружаем и устанавливаем nats-server
    RUN wget https://github.com/nats-io/nats-server/releases/download/v2.9.15/nats-server-v2.9.15-linux-amd64.tar.gz && \
        tar -zxf nats-server-*.tar.gz && \
        cp nats-server-*-linux-amd64/nats-server /usr/bin/ && \
        rm -rf nats-server-*-linux-amd64 nats-server-*.tar.gz
    
    # Загружаем и устанавливаем natscli
    RUN wget https://github.com/nats-io/natscli/releases/download/v0.0.35/nats-0.0.35-amd64.deb && \
        dpkg -i nats-0.0.35-amd64.deb && \
        rm nats-0.0.35-amd64.deb
    
    # Команда для запуска NATS сервера с JetStream и другими параметрами
    CMD ["nats-server", "-js", "--store_dir", "/app/data", "--net", "nats_server", "--addr", "0.0.0.0", "--port", "4222", "--http_port", "8222", "--debug", "--trace"]
    # Как можете видеть, я запускаю сервер с параметром --net nats_server, так как так у меня называется служба в docker-compose.yml

Еще небольшое замечание. Если вы используете nats, то вы должны создавать stream. Либо делаете это динамически в коде, либо вручную, тогда в конец вышеприведенного докер файла необходимо добавить еще команду по запуску потока. Официальная документация по запуску потока тут: https://docs.nats.io/running-a-nats-service/nats_admin/jetstream_admin/streams  
  
  
  
-

**Если вы хотели бы дополнить или что-то поправить, буду рад вашим комментариям https://t.me/EVGENIY_JEM**
