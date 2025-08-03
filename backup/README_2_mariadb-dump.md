# Работа с mariadb-dump

[Назад к главному README](README.md)

**mariadb-dump** — это логическая утилита резервного копирования, аналог mysqldump. Она создаёт SQL-дампы, содержащие команды CREATE и INSERT.


```bash
mariadb-dump -u root -p \
    --single-transaction \
    --add-drop-table \
    --add-locks \
    --create-options \
    --disable-keys \
    --extended-insert \
    --quick \
    --set-charset \
    --events \
    --routines \
    --triggers \
    --all-databases | gzip > /backups/full_backup_$(date +%F).sql.gz
```
