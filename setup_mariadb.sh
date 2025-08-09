#!/bin/bash

# Скрипт для установки и настройки MariaDB на AlmaLinux
ROOT_DB_PASSWORD="Ww12345"  # Пароль от root СУБД MariaDB.
USER="evgen"                # Имя пользователя, который будет создан в СУБД MariaDB.
USER_PASSWORD="Xx12345"     # Пароль от $USER СУБД MariaDB.
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf" # Путь к файлу конфигурации MariaDB.

### ЦВЕТА ###
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ###
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# ---------------------------------------------------------------------------------------


# --- Проверка запуска через sudo ---
if [ -z "$SUDO_USER" ]; then
    errorprint "Пожалуйста, запустите скрипт через sudo."
    exit 1
fi

magentaprint "Устанавливаем сервер MariaDB и клиент"
dnf install -y mariadb-server mariadb

magentaprint "Включаем автозапуск и стартуем MariaDB"
systemctl enable --now mariadb

magentaprint "Настройка firewall, открываем 3306 порт"
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --reload

magentaprint "Создание директории для временных файлов"
mkdir -p /var/lib/mysql_tmp
chown mysql:mysql /var/lib/mysql_tmp

magentaprint "Проверяем статус MariaDB"
systemctl status mariadb --no-pager

magentaprint "Проверяем версию MariaDB"
mariadb --version

magentaprint "Создание пользователя и установка пароля root"
# Подключаемся через сокет (root без пароля)
mariadb -u root --protocol=SOCKET <<SQL
CREATE USER IF NOT EXISTS '$USER'@'%' IDENTIFIED BY '$USER_PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%' WITH GRANT OPTION;
ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$ROOT_DB_PASSWORD');
FLUSH PRIVILEGES;
SQL

magentaprint "Бэкапим текущий конфиг, если существует"
if [[ -f "$MARIADB_CONF" ]]; then
    cp -a "$MARIADB_CONF" "${MARIADB_CONF}.bak.$(date +%Y%m%d%H%M%S)"
fi

magentaprint "Добавляем рекомендуемые параметры тюнинга MariaDB"
cat <<EOF > "$MARIADB_CONF"
[mysqld]
# Слушать все сетевые интерфейсы
bind_address = 0.0.0.0

# Путь к Unix-сокету для локальных подключений
socket = /var/lib/mysql/mysql.sock

# Директория для хранения данных
datadir = /var/lib/mysql

# Директория для временных файлов (сортировка, временные таблицы)
tmpdir = /var/lib/mysql_tmp

# Файл общего лога (все запросы, если general_log = ON)
general-log-file = /var/log/mariadb/mariadb.log
# Отключить общий лог (запись всех SQL-запросов, влияет на производительность)
general_log = OFF
# Файл для записи ошибок сервера
log-error=/var/log/mariadb/mariadb.log.err
# Уровень логирования предупреждений (2 = логировать ошибки и предупреждения)
log_warnings = 2

# Файл с PID-идентификатором процесса
pid-file=/run/mariadb/mariadb.pid

## Ускорит резолвинг
# Отключить кэширование DNS-имен (ускоряет подключения)
skip-host-cache
# Не разрешать имена хостов (только IP, ускоряет соединения)
skip-name-resolve

# Время неактивности (в секундах), после которого соединение закрывается
wait_timeout = 300

# Максимальное количество одновременных подключений
max_connections = 100

# Хранить каждую InnoDB-таблицу в отдельном файле (упрощает управление)
innodb_file_per_table = on
# Настройка durability InnoDB. (0 = быстрее, но возможна потеря данных при сбое); 1 — максимальная надежность.
# 0 = максимум производительности, но при сбое можно потерять последние транзакции.
# 1 (рекомендуется) = полная надежность (но медленнее).
# 2 = компромисс (данные сохраняются в ОС, но не обязательно на диск).
innodb_flush_log_at_trx_commit = 1
# Размер буфера пула InnoDB (кэш данных и индексов). Обычно 60–80% от объема RAM сервера.
innodb_buffer_pool_size = 1G
# Размер файла лога транзакций InnoDB
innodb_log_file_size = 256M
# Размер буфера лога транзакций InnoDB
innodb_log_buffer_size = 128M
# Метод записи данных на диск (O_DIRECT = минуя кэш ОС)
innodb_flush_method=O_DIRECT
# Формат файлов InnoDB (Barracuda поддерживает сжатие)
innodb_file_format = Barracuda

## Query Cache (выключено в новых версиях, оставлено явно)
# Размер кэша запросов
query_cache_size = 0
# Тип кэша запросов (ON = кэшировать все, кроме SELECT SQL_NO_CACHE)
query_cache_type = 0

# Размер временных таблиц в памяти
tmp_table_size = 64M
max_heap_table_size = 64M

# Включить лог медленных запросов
slow_query_log = on
# Записывать медленные запросы (если выполнение > 5 секунд)
long_query_time = 5
# Файл для записи медленных запросов
slow_query_log_file = /var/log/mariadb/slow.log

# Установка кодировки по умолчанию.
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
EOF

magentaprint "Перезапускаем MariaDB для применения настроек"
systemctl restart mariadb

magentaprint "Базовая настройка завершена."
magentaprint "Запустите скрипт, который поможет улучшить безопасность:"
greenprint "mysql_secure_installation"
