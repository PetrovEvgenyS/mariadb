# MariaDB Репликация: Скрипты настройки Master и Slave

## Описание

В данном репозитории представлены два bash-скрипта для автоматизации настройки репликации MariaDB:
- **setup_master.sh** — конфигурирует сервер как мастер, создает пользователя для репликации, включает бинарные логи и подготавливает данные для слейва.
- **setup_slave.sh** — конфигурирует сервер как слейв, подключает его к мастеру и запускает процесс репликации.

## Требования

- MariaDB установлен и запущен на обоих серверах (master и slave).
- Доступ root к MariaDB на обоих серверах.
- SSH-доступ между серверами для передачи резервной копии.

## Порядок настройки

### 1. Настройка Master-сервера

1. Отредактируйте переменные в `setup_master.sh` при необходимости (IP-адрес слейва, пароли и имя базы).
2. Запустите скрипт на мастер-сервере:
   ```bash
   sudo ./setup_master.sh
   ```
3. После выполнения скрипта сохраните значения `File` и `Position` из вывода `SHOW MASTER STATUS` — они понадобятся для настройки слейва.
4. Передайте резервную копию базы данных на слейв:
   ```bash
   scp /tmp/master_backup.sql <USER>@<SLAVE_IP>:/tmp/
   ```

### 2. Настройка Slave-сервера

1. Получите резервную копию базы данных с мастера (если ещё не передавали):
   ```bash
   scp /tmp/master_backup.sql <USER>@<SLAVE_IP>:/tmp/
   ```

2. Восстановите резервную копию базы данных на слейве:
   ```bash
   mysql -u root -p < /tmp/master_backup.sql
   ```

3. Отредактируйте переменные в `setup_slave.sh` (IP мастера, пароли, имя бинарного лога и позицию — используйте значения из мастера).

4. Запустите скрипт на слейв-сервере:
   ```bash
   sudo ./setup_slave.sh
   ```

5. Проверьте статус репликации — скрипт выведет результат команды:
   ```sql
   SHOW SLAVE STATUS\G;
   ```
## Проверка состояния репликации

```sql
SHOW SLAVE STATUS\G;
```
либо
```sql
SHOW REPLICA STATUS\G;
```

### Параметры репликации MariaDB

| Поле                              | Что значит                                                                 | Что должно быть                            |
|-----------------------------------|------------------------------------------------------------------------------|---------------------------------------------|
| `Slave_IO_Running`                | Поток загрузки бинарных логов с мастера                            	 | `Yes`                                       |
| `Slave_SQL_Running`              | Поток применения событий из лога на слейве                                  | `Yes`                                       |
| `Seconds_Behind_Master`          | Задержка реплики в секундах                                                 | `0` или близко к `0`                        |
| `Last_IO_Error`                  | Последняя ошибка в IO-потоке                                                | Пусто                                       |
| `Last_SQL_Error`                 | Последняя ошибка в SQL-потоке                                               | Пусто                                       |
| `Read_Master_Log_Pos`            | Позиция, до которой IO-поток прочитал бинлоги                               | ≈ `Exec_Master_Log_Pos`                     |
| `Exec_Master_Log_Pos`            | Позиция, до которой SQL-поток применил бинлоги                              | ≈ `Read_Master_Log_Pos`                     |
| `Master_Log_File`                | Имя текущего бинарного лога на мастере                                      | Совпадает с `Relay_Master_Log_File`         |
| `Relay_Master_Log_File`          | Лог-файл, который сейчас исполняется                                        | Совпадает с `Master_Log_File`               |
| `Relay_Log_Space`                | Размер relay-логов на диске                                                 | Не растёт бесконтрольно                     |
| `Slave_IO_State`                 | Что делает IO-поток сейчас                                                  | `Waiting for master to send event`          |
| `Slave_SQL_Running_State`        | Что делает SQL-поток сейчас                                                 | `Slave has read all relay log` или idle     |
| `Last_IO_Errno`, `Last_IO_Error` | Код и текст последней IO-ошибки                                            | `0`, пусто                                   |
| `Last_SQL_Errno`, `Last_SQL_Error` | Код и текст последней SQL-ошибки                                          | `0`, пусто                                   |
| `Master_Host`                    | IP или имя мастера                                                          | Соответствует конфигурации                  |
| `Master_User`                    | Пользователь для подключения к мастеру                                      | Репликационный пользователь (`REPLICATION SLAVE`) |
| `Master_Port`                    | Порт подключения к мастеру                                                  | `3306` (или ваш кастомный)                  |
| `Connect_Retry`                  | Интервал повторного подключения (секунды)                                   | Обычно `60`                                 |
| `Using_Gtid`                     | Используется ли GTID                                                        | `Yes` (если настроено)                      |
| `Gtid_IO_Pos`                    | Текущая позиция GTID                                                        | Заполнено, если `Using_Gtid = Yes`          |
| `Auto_Position`                  | Используется ли авто-позиция (GTID)                                         | `1` (если включён GTID)                     |
| `SQL_Delay`                      | Задержка применения SQL событий                                             | `0` (если не используете отложенную реплику)|
| `SQL_Remaining_Delay`            | Сколько ещё ждать до применения событий                                     | `NULL` или `0`                              |
| `Parallel_Mode`                  | Режим параллельного исполнения SQL-потока                                   | `optimistic`, `strict`, или `conservative`  |
| `Master_Server_Id`              | `server_id` мастера                                                        | Совпадает с ID мастера                      |
| `Relay_Log_File`    | Имя текущего relay-лога, из которого SQL-поток применяет события            | Обновляется синхронно с `Relay_Master_Log_File`  |
| `Relay_Log_Pos`     | Текущая позиция чтения внутри `Relay_Log_File`                              | Продвигается вперёд, обычно ≈ `Exec_Master_Log_Pos` |


### Быстрый шаблон оценки:
Если:
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`
- `Seconds_Behind_Master: 0`
- `Last_IO_Error: [пусто]`
- `Last_SQL_Error: [пусто]`

Всё работает нормально.



## Переключение ролей при отказе мастера (Failover)

Если мастер недоступен, можно назначить одного из слейвов новым мастером, а старый мастер — подключить к нему как реплику после восстановления.

### 1. Назначение нового мастера
1. Выбери актуального слейва (у которого `Seconds_Behind_Master = 0` или минимальная задержка).
2. Останови репликацию на этом слейве:
   ```sql
   STOP SLAVE;
   RESET SLAVE ALL;
   ```
3. Включи бинарные логи (обязательно для работы как мастера).  
   Отредактируй `/etc/my.cnf.d/mariadb-server.cnf`, добавь:
   ```ini
   [mysqld]
   bind-address= 127.0.0.1,10.10.10.2
   server-id=2
   log_bin = /var/lib/mysql/mariadb-bin.log
   log_bin_index = /var/lib/mysql/mariadb-bin.index
   binlog_ignore_db = information_schema, mysql, performance_schema
   ```
   Перезапусти MariaDB:
   ```bash
   systemctl restart mariadb
   ```
   После этого убедись, что `SHOW MASTER STATUS;` показывает файл binlog и позицию.
4. Убедись, что сервер может принимать записи:
   ```sql
   SET GLOBAL read_only = OFF;
   ```
5. Создай на новом мастере пользователя для репликации (если ещё нет):
   ```sql
   CREATE USER 'replicator'@'%' IDENTIFIED BY 'Ee123456';
   GRANT REPLICATION SLAVE ON *.* TO 'replicator'@'%';
   FLUSH PRIVILEGES;
   ```
6. С этого момента новый сервер работает как **Master**.

### 2. Переподключение остальных слейвов к новому мастеру
1. На каждом слейве останови старую репликацию:
   ```sql
   STOP SLAVE;
   RESET SLAVE ALL;
   ```

2. Включи бинарные логи (обязательно для работы как мастера).  
   Отредактируй `/etc/my.cnf.d/mariadb-server.cnf`, добавь:
   ```ini
   [mysqld]
   bind-address= 127.0.0.1,10.10.10.2
   server-id=2
   log_bin = /var/lib/mysql/mariadb-bin.log
   log_bin_index = /var/lib/mysql/mariadb-bin.index
   binlog_ignore_db = information_schema, mysql, performance_schema
   ```
   Перезапусти MariaDB:
   ```bash
   systemctl restart mariadb
   ```

3. Подключи слейв к новому мастеру:
   ```sql
   CHANGE MASTER TO
     MASTER_HOST='<NEW_MASTER_IP>',
     MASTER_USER='replicator',
     MASTER_PASSWORD='Ee123456',
     MASTER_LOG_FILE='<NEW_MASTER_LOG_FILE>',
     MASTER_LOG_POS=<NEW_MASTER_LOG_POS>;
   START SLAVE;
   ```
3. Проверь состояние:
   ```sql
   SHOW SLAVE STATUS\G;
   ```

### 3. Подключение старого мастера как слейва
Когда старый мастер восстановлен:
1. Очисти его от старых настроек репликации:
   ```sql
   RESET SLAVE ALL;
   ```

2. Удали старые данные, чтобы исключить конфликты (можно удалить только пользовательские базы или полностью datadir):
   ```sql
   DROP DATABASE IF EXISTS example_db;
   CREATE DATABASE example_db;
   ```
   или радикально (удалить весь datadir и пересоздать):
   ```bash
   systemctl stop mariadb
   rm -rf /var/lib/mysql/*
   mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
   systemctl start mariadb
   ```

3. Перед подключением к новому мастеру **обязательно пересинхронизируй данные**, так как на старом мастере могли остаться записи, которых нет у нового.  
   Иначе будут ошибки (`Duplicate entry`, `Row not found` и т. д.).  
   Проще всего сделать полный дамп с нового мастера и восстановить его на старом:
   ```bash
   mysqldump -h <NEW_MASTER_IP> -u root -p --all-databases > /tmp/master_dump.sql
   mysql -u root -p < /tmp/master_dump.sql
   ```

4. Включи режим `read_only`:
   ```sql
   SET GLOBAL read_only = ON;
   ```

5. Подключи его к новому мастеру:
   ```sql
   CHANGE MASTER TO
     MASTER_HOST='<NEW_MASTER_IP>',
     MASTER_USER='replicator',
     MASTER_PASSWORD='Ee123456',
     MASTER_LOG_FILE='<NEW_MASTER_LOG_FILE>',
     MASTER_LOG_POS=<NEW_MASTER_LOG_POS>;
   START SLAVE;
   ```

6. Убедись, что он синхронизировался:
   ```sql
   SHOW SLAVE STATUS\G;
   ```