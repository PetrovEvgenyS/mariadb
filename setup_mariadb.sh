#!/bin/bash

# Скрипт для установки и настройки MariaDB на AlmaLinux
ROOT_DB_PASSWORD="Ww12345"  # Пароль от root СУБД MariaDB.
USER="evgen"                # Имя пользователя, который будет создан в СУБД MariaDB.
USER_PASSWORD="Xx12345"     # Пароль от $USER СУБД MariaDB.

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

magentaprint "Включаем MariaDB в автозагрузку и запускаем"
systemctl enable mariadb && systemctl start mariadb

magentaprint "Настройка firewall, открываем 3306 порт"
firewall-cmd --permanent --add-port=3306/tcp
firewall-cmd --reload

magentaprint "Проверяем статус MariaDB"
sudo systemctl status mariadb --no-pager

magentaprint "Проверяем версию MariaDB"
mariadb --version

magentaprint "Создание пользотеля в СУБД MariaDB и измение пароля root"
mysql -u root -pEnter -e "CREATE USER '$USER'@'%' IDENTIFIED BY '$USER_PASSWORD';"
mysql -u root -pEnter -e "GRANT ALL PRIVILEGES ON *.* TO '$USER'@'%';"
mysql -u root -pEnter -e "FLUSH PRIVILEGES;"
mysql -u root -pEnter -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_DB_PASSWORD';"

magentaprint "Запустите скрипт, который поможет улучшить безопасность:"
greenprint "mysql_secure_installation"
