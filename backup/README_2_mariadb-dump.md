# Работа с mariadb-dump

[Назад к главному README](README.md)

**mariadb-dump** — это логическая утилита резервного копирования, аналог mysqldump. Она создаёт SQL-дампы, содержащие команды CREATE и INSERT.

```bash
mariadb-dump -h localhost -P 3306 -u root -p \
    --single-transaction \
    --add-drop-table \
    --add-locks \
    --create-options \
    --disable-keys \
    --extended-insert \
    --quick \
    --default-character-set=utf8mb4 \
    --hex-blob \
    --events \
    --routines \
    --triggers \
    --all-databases | gzip > /backups/full_backup_$(date +%F).sql.gz
```

**Параметры подключения**
- `-h localhost` — хост MariaDB-сервера (здесь — локальная машина).
- `-P 3306` — порт для подключения (по умолчанию 3306).
- `-u root` — имя пользователя для подключения.
- `-p` — запросить пароль при подключении.

**Опции бэкапа**
- `--single-transaction` — делает дамп в рамках одной транзакции, обеспечивая согласованность данных без блокировки таблиц (работает только для движка InnoDB).
- `--add-drop-table` — перед каждой командой CREATE TABLE добавляет DROP TABLE IF EXISTS, чтобы при восстановлении удалять старую таблицу перед созданием.
- `--add-locks` — оборачивает вставку данных в LOCK TABLES/UNLOCK TABLES для ускорения восстановления.
- `--create-options` — сохраняет все специфичные параметры создания таблиц (ENGINE=, CHARSET=, и т. д.).
- `--disable-keys` — отключает индексы перед массовой вставкой данных и включает их после, что ускоряет восстановление.
- `--extended-insert` — объединяет несколько строк INSERT в одну команду, уменьшая размер дампа и ускоряя импорт.
- `--quick` — выгружает данные построчно без предварительной загрузки в память (уменьшает расход RAM).
- `--default-character-set=utf8mb4` — устанавливает кодировку дампа (рекомендуется для поддержки emoji и всех Unicode-символов).
- `--hex-blob` — экспортирует бинарные поля (BLOB, VARBINARY) в шестнадцатеричном виде для корректного восстановления.
- `--events` — включает экспорт событий (EVENT).
- `--routines` — включает экспорт процедур и функций.
- `--triggers` — включает экспорт триггеров.
- `--all-databases` — делает дамп всех баз на сервере.

**Вывод и сжатие**
- `| gzip` — сжимает дамп на лету для экономии места.

- `> /backups/full_backup_$(date +%F).sql.gz` — сохраняет файл с именем, содержащим текущую дату.

## Востановление из дампа

```bash
gunzip < /backups/full_backup_2025-08-09.sql.gz | mariadb -u root -p
```

---

[Назад к главному README](README.md)
