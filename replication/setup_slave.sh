#!/bin/bash

# Переменные для конфигурации
REPLICA_USER="replicator"   # Имя пользователя для репликации
REPLICA_PASSWORD="Ee123456" # Пароль для пользователя репликации
ROOT_PASSWORD="Ww12345"     # Пароль пользователя root
MASTER_IP="10.100.10.1"     # IP-адрес master-сервера
MASTER_LOG_FILE="mariadb-bin.000001"  # Имя бинарного лога с мастер-сервера (взято из MASTER_STATUS)
MASTER_LOG_POS=800          # Позиция бинарного лога (взято из MASTER_STATUS)
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf" # Путь к файлу конфигурации MariaDB.

# Настраиваем MariaDB как слейв
cat <<EOF >> $MARIADB_CONF

server-id= 2                # Уникальный идентификатор слейва
EOF

# Перезапускаем MariaDB для применения конфигурации
systemctl restart mariadb

# Настраиваем слейв для репликации с мастера
mysql -u root -p$ROOT_PASSWORD -e "CHANGE MASTER TO MASTER_HOST='$MASTER_IP', MASTER_USER='$REPLICA_USER', \
                MASTER_PASSWORD='$REPLICA_PASSWORD', MASTER_LOG_FILE='$MASTER_LOG_FILE', MASTER_LOG_POS=$MASTER_LOG_POS;"

# Запускаем процесс репликации
mysql -u root -p$ROOT_PASSWORD -e "START SLAVE;"

# Проверяем статус репликации
SLAVE_STATUS=$(mysql -u root -p$ROOT_PASSWORD -e "SHOW SLAVE STATUS\G")
echo "Репликация настроена. Текущий статус слейва:"
echo "$SLAVE_STATUS"
