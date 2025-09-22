#!/bin/bash

# Переменные для конфигурации
REPLICA_USER="replicator"   # Имя пользователя для репликации
REPLICA_PASSWORD="Ee123456" # Пароль для пользователя репликации
ROOT_PASSWORD="Ww12345"     # Пароль пользователя root
SLAVE_IP="10.100.10.2"      # IP-адрес slave-сервера
DATABASE="example_db"       # Имя базы данных для репликации
MARIADB_CONF="/etc/my.cnf.d/mariadb-server.cnf" # Путь к файлу конфигурации MariaDB.

# Настраиваем MariaDB как мастер
cat <<EOF >> $MARIADB_CONF

server-id = 1               # Уникальный идентификатор мастера.

log_bin = /var/lib/mysql/mariadb-bin.log  # Включает бинарные логи, необходимые для репликации.
log_bin_index = /var/lib/mysql/mariadb-bin.index # Хранит список всех бинарных файлов, что важно для репликации и восстановления данных.

expire_logs_days = 3   # Устанавливает количество дней, через которое старые бинарные логи (bin_log) будут автоматически удалены.

# binlog_do_db = $DATABASE  # Используется для репликации только определенных баз данных.
binlog_ignore_db = information_schema, mysql, performance_schema # Исключает определенные базы данных из репликации (в данном примере, исключены служебных базы).
EOF

# Перезапускаем MariaDB для применения конфигурации
systemctl restart mariadb

# Создаем пользователя для репликации и предоставляем необходимые права
mysql -u root -p$ROOT_PASSWORD -e "CREATE USER '$REPLICA_USER'@'$SLAVE_IP' IDENTIFIED BY '$REPLICA_PASSWORD';"
mysql -u root -p$ROOT_PASSWORD -e "GRANT REPLICATION SLAVE ON *.* TO '$REPLICA_USER'@'$SLAVE_IP';"
mysql -u root -p$ROOT_PASSWORD -e "FLUSH PRIVILEGES;"

# Блокируем БД на запись:
mysql -u root -p$ROOT_PASSWORD -e "SET GLOBAL read_only = ON;"

# Отображаем текущий статус мастера, чтобы скопировать данные для настройки слейва
MASTER_STATUS=$(mysql -u root -p$ROOT_PASSWORD -e "SHOW MASTER STATUS\G")
echo "Настройка завершена. Сохраните следующие данные для настройки слейва:"
echo "$MASTER_STATUS"

# Делаем резервную копию всех баз:
echo " "
echo "Делаем backpup БД: /tmp/master_backup.sql"
mariadb-dump -u root -p$ROOT_PASSWORD --all-databases > /tmp/master_backup.sql

# Снимаем блокировку БД на запись:
mysql -u root -p$ROOT_PASSWORD -e "SET GLOBAL read_only = OFF;"
echo " "
echo "Скопируйте backup БД Мастера на Slave:"
echo "scp /tmp/master_backup.sql root@$SLAVE_IP:/tmp/"
echo " "
echo "Выполните команду на Slave:"
echo "mysql -u root -p < /tmp/master_backup.sql"
echo " "
