#!/bin/bash

# Переменные для конфигурации
REPLICA_USER="replicator"               # Имя пользователя для репликации
REPLICA_PASSWORD="your_password"        # Пароль для пользователя репликации
ROOT_PASSWORD="your_password"           # Пароль пользователя root
MASTER_IP="10.100.10.1"                 # IP-адрес master-сервера
MASTER_LOG_FILE="mariadb-bin.000001"    # Имя бинарного лога с мастер-сервера (взято из MASTER_STATUS)
MASTER_LOG_POS=800                      # Позиция бинарного лога (взято из MASTER_STATUS)
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf" # Путь к файлу конфигурации MariaDB. AlmaLinux
#MARIADB_CONF="/etc/mysql/mariadb.conf.d/50-server.cnf" # Путь к файлу конфигурации MariaDB. Ubuntu

# Настраиваем MariaDB как слейв
cat <<EOF >> $MARIADB_CONF

### replication

# Уникальный идентификатор сервера.
server-id = 2

# Включает бинарные логи, необходимые для репликации.
log_bin = /var/lib/mysql/mariadb-bin.log

# Хранит список всех бинарных файлов, что важно для репликации и восстановления данных.
log_bin_index = /var/lib/mysql/mariadb-bin.index

# Указывает, где slave будет хранить лог репликации.
relay_log = /var/lib/mysql/relay-bin.log

# Хранит список всех релей-логов, полезно для управления репликацией.
relay_log_index = /var/lib/mysql/relay-bin.index

# Исключает определенные базы данных из репликации (в данном примере, исключены служебные базы).
binlog_ignore_db = information_schema, mysql, performance_schema
EOF

# Перезапускаем MariaDB для применения конфигурации
systemctl restart mariadb

# Настраиваем слейв для репликации с мастера
mariadb -u root -p$ROOT_PASSWORD -e "CHANGE MASTER TO MASTER_HOST='$MASTER_IP', MASTER_USER='$REPLICA_USER', \
                MASTER_PASSWORD='$REPLICA_PASSWORD', MASTER_LOG_FILE='$MASTER_LOG_FILE', MASTER_LOG_POS=$MASTER_LOG_POS;"

# Запускаем процесс репликации
mariadb -u root -p$ROOT_PASSWORD -e "START SLAVE;"

# Проверяем статус репликации
SLAVE_STATUS=$(mariadb -u root -p$ROOT_PASSWORD -e "SHOW SLAVE STATUS\G")
echo "Репликация настроена. Текущий статус слейва:"
echo "$SLAVE_STATUS"
