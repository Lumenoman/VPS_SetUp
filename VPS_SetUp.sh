#!/bin/bash
# ========================================
# Универсальный скрипт базовой настройки VPS
# Поддерживаемые ОС: Debian/Ubuntu
# Авторы в порядке вклада: ChatGPT, Grok, DeepSeek, Lumenoman
#
# Сохрани скрипт на сервере:
# mkdir /usr/local/bin/VPS_SetUp/
# nano /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
# Сделай исполняемым:
# chmod +x /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
# Запусти: /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
# Скрипт логирует всё в /usr/local/bin/VPS_SetUp/setup.log
# И сохраняет параметры в /usr/local/bin/VPS_SetUp/server_env.txt
# ========================================

clear
echo "Начинаем..."

# Script Version
SVERSION="2.16.4.18"

# Global massive
echo "Создание массива для отчетов..."
SUCCESS=()
FAILED=()
WARNINGS=()

# Add results
echo "Создание функций для массива с отчетами..."
add_success() {
SUCCESS+=("$1")
info "$1"
}
add_failed() {
FAILED+=("$1")
fail "$1"
}
add_warning() {
WARNINGS+=("$1")
warn "$1"
}
info() {
echo "✓ $1"
}
warn() {
echo "⚠ $1"
}
fail() {
echo "✗ $1"
}

# root check
echo "Проверка наличия прав root..."
if [[ $EUID -ne 0 ]]; then
add_warning  "Нет прав root, перезапускаемся..."
echo "Запрос прав root..."
exec sudo "$0" "$@"
else
add_success "Пользователь имеет права Root"
fi

# Bash Safety
echo "Настройка режима работы Bash..."
set -euo pipefail
echo "Настройка обработки ошибок..."
trap 'echo; echo "✗ Ошибка на строке $LINENO"; add_failed "Ошибка на строке $LINENO"; exit 1' ERR

# OS check
echo "Проверка ОС на совместимость..."
source /etc/os-release
if [[ "$ID" == "debian" || "$ID" == "ubuntu" || "$ID_LIKE" == *debian* ]]; then
echo "Обнаружена ОС: $PRETTY_NAME"
add_success "ОС поддерживается"
else
add_failed "Поддерживаются только Debian/Ubuntu"
add_failed "Выход"
exit 1
fi

# Make env
echo "Создание переменных для рабочих файлов..."
SETUP_DIR="/usr/local/bin/VPS_SetUp"
mkdir -p "$SETUP_DIR"
ENV_FILE="$SETUP_DIR/server_env.txt"
LOG_FILE="$SETUP_DIR/setup.log"

# Log
echo "Очистка предидущих логов и параметров..."
rm -f "$ENV_FILE"
rm -f "$LOG_FILE"
echo "Запуск логирования..."
exec > >(tee -a "$LOG_FILE") 2>&1

# General functions
echo "Создание функций..."

pause() {
echo
read -n1 -s -r -p "Для продолжения нажмите любую клавишу..."
echo
}

section() {
echo
echo "========================================"
echo "$1"
echo "========================================"
echo
}

confirm() {
local MESSAGE="$1"
while true; do
read -rp "$MESSAGE [Y/n]: " ANSWER
case "${ANSWER,,}" in
""|y|yes)
return 0
;;
n|no)
return 1
;;
*)
echo "Введите Y или N."
;;
esac
done
}

save_env() {
echo "$1" >> "$ENV_FILE"
}

# Set new ports
read_ports() {
if ! confirm "Произвести смену порта SSH?"; then
return
fi
echo "Задаем новый порт для SSH..."
read -rp "Введите новый SSH порт (49152-65535) или Enter для случайного: " NPORT
if [[ -z "$NPORT" ]]; then
NPORT=$(shuf -i 49152-65535 -n 1)
fi
while ! [[ "$NPORT" =~ ^[0-9]+$ ]] || \
(( NPORT < 49152 || NPORT > 65535 )) || \
ss -ltn | grep -q ":${NPORT} "; do
echo "✗ Некорректный или занятый порт."
read -rp "Введите другой порт (или Enter для случайного): " NPORT
[[ -z "$NPORT" ]] && NPORT=$(shuf -i 49152-65535 -n 1)
done
add_success "Новый SSH порт $NPORT задан успешно"
add_warning "Требуется обязательная настройка UFW!"
if ! confirm "Задать дополнительный порт XPort для будщих сервисов?"; then
return
fi
echo "Задаем дополнительный порт XPort для будщих сервисов..."
read -rp "Введите XPort, или нажмите Enter для 2442: " XPORT
XPORT=${XPORT_INPUT:-2442}
while ! [[ "$XPORT" =~ ^[0-9]+$ ]] || \
(( XPORT < 1 || XPORT > 65535 )) || \
(( XPORT == NPORT )) || \
ss -ltn | grep -q ":${XPORT} "; do
echo "✗ Некорректный или занятый порт"
read -rp "Введите другой XPort (или Enter для 2442): " XPORT
XPORT=${XPORT:-2442}
done
add_success "XPort $XPORT задан успешно"
add_warning "Требуется обязательная настройка UFW!"
save_env "New SSH port: $NPORT"
save_env "Addons port: $XPORT"
save_env "Требуется обязательная настройка UFW!"
}

# Make server_env
init_server_env() {
echo "Определение основных параметров системы..."
mkdir -p "$SETUP_DIR"
HOSTNAME=$(hostname)
IP=$(curl -4 -fsSL ifconfig.me || echo "unknown")
OS_INFO=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
RAM=$(free -h | awk '/^Mem:/ {print $2}')
{
echo "========================================"
echo "Server Environment"
echo "========================================"
echo
echo "OS: $OS_INFO Like $ID_LIKE"
echo "RAM: $RAM"
echo "Hostname: $HOSTNAME"
echo "IP: $IP"
echo "Script version: $SVERSION"
echo "Created: $(date)"
echo
} > "$ENV_FILE"
}

# Show info
show_info() {
echo "Информация о сервере:"
echo
cat "$ENV_FILE"
}

# End caps / Plugs
update_script() {
section "Обновление скрипта"
local CURRENT_VERSION="$SVERSION"
local REMOTE_VERSION
local SCRIPT_URL
local SCRIPT_PATH
local TEMP_FILE
SCRIPT_URL="https://raw.githubusercontent.com/Lumenoman/VPS_SetUp/main/VPS_SetUp.sh"
SCRIPT_PATH="/usr/local/bin/VPS_SetUp/VPS_SetUp.sh"
echo "Проверка обновлений..."
TEMP_FILE=$(mktemp)
if ! curl -fsSL "$SCRIPT_URL" -o "$TEMP_FILE"; then
echo "✗ Не удалось получить информацию о новой версии"
echo "Попробуйте повторить обновление"
rm -f "$TEMP_FILE"
return 1
fi
REMOTE_VERSION=$(grep -m1 '^SVERSION=' "$TEMP_FILE" | cut -d'"' -f2)
if [[ -z "$REMOTE_VERSION" ]]; then
echo "✗ Не удалось определить версию из источника обновлений"
echo "Попробуйте повторить обновление"
rm -f "$TEMP_FILE"
return 1
fi
if [[ "$CURRENT_VERSION" == "$REMOTE_VERSION" ]]; then
echo "✓ Последняя версия v$CURRENT_VERSION уже установлена"
rm -f "$TEMP_FILE"
return 0
fi
if [[ "$(printf '%s\n' "$CURRENT_VERSION" "$REMOTE_VERSION" | sort -V | head -n1)" == "$REMOTE_VERSION" ]]; then
echo "⚠ Уже установлена более новая версия: v$CURRENT_VERSION"
echo "Источник обновлений содержит версию: v$REMOTE_VERSION"
rm -f "$TEMP_FILE"
return 0
fi
echo "Текущая версия: v$CURRENT_VERSION"
echo "Доступная версия: v$REMOTE_VERSION"
if ! confirm "Обновить VPSSetUp?"; then
rm -f "$TEMP_FILE"
return
fi
if ! bash -n "$TEMP_FILE"; then
echo "✗ Новая версия содержит синтаксическую ошибку"
echo "Попробуйте повторить обновление"
rm -f "$TEMP_FILE"
return 1
fi
chmod +x "$TEMP_FILE"
mv "$TEMP_FILE" "$SCRIPT_PATH"
echo "✓ VPSSetUp успешно обновлен до версии v$REMOTE_VERSION"
echo "Перезапустите скрипт!"
}

reboot_server() {
section "Перезагрузка сервера"
if confirm "Перезагрузить сервер?"; then
echo "Перезагрузка..."
clear
reboot
pause
else
echo "Отмена"
return
fi
}

change_root_password() {
section "Смена пароля Root"
if ! confirm "Сменить пароль Root?"; then
return
fi
NEW_PASS=$(tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' \
< /dev/urandom | head -c32 || true)
echo
echo "✓ Пароль сгенерирован. Новый пароль:"
echo "$NEW_PASS"
echo
read -rp "Сохраните пароль и нажмите Enter..."
echo "root:$NEW_PASS" | chpasswd
save_env "New root password: $NEW_PASS"
add_success "Пароль Root изменен"
}

update_system() {
section "Обновление системы"
if ! confirm "Обновить систему?"; then
return
fi
echo "Обновляем систему..."
apt-get update
apt-get full-upgrade -y
echo "Очистка от ненужных пакетов..."
apt-get autoremove -y
apt-get clean
echo "Проверка необходимости перезагрузки системы..."
if [[ -f /var/run/reboot-required ]]; then
echo
echo "⚠ Для завершения установки обновлений требуется перезагрузка"
echo
if confirm "Перезагрузить сервер сейчас?"; then
reboot
else
add_warning "Требуется перезагрузка системы"
fi
else
echo "✓ Перезагрузка не требуется"
add_success "Обновление системы завершено"
save_env "System update successfully"
fi
}

install_packages() {
section "Установка пакетов"
if ! confirm "Установить все рекомендуемые пакеты?"; then
return
fi
echo "Установка дополнительных пакетов..."
apt-get install -y curl wget git nano mc htop btop jq dnsutils net-tools ca-certificates gnupg lsb-release golang-go certbot chrony ufw fail2ban unattended-upgrades
if systemctl is-active --quiet chrony
then
add_success "Сервис Chrony запущен"
else
add_failed "Сервис Chrony не запущен"
fi
add_success "Установка допольнительных пакетов завершена"
add_warning "Возможны ошибки, требуется ручная проверка логов"
add_warning "Проверте, все ли пакеты были установлены"
save_env "Packages installed, for exceptions errors check log manually"
}

harden_ssh() {
section "Конфигурирование SSH для повышения базовой безопасности"
if ! confirm "Произвести конфигурирование SSH?"; then
return
fi
echo "Ужесточение конфигурации SSH..."
cat >/etc/ssh/sshd_config.d/99-hardening.conf <<'EOF'
LoginGraceTime 30
PermitRootLogin prohibit-password
MaxAuthTries 3
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no
KbdInteractiveAuthentication no
X11Forwarding no
ClientAliveInterval 300
ClientAliveCountMax 2
UseDNS no
EOF
echo "Проверка конфигурации SSH..."
if ! sshd -t; then
echo "✗ Ошибка конфигурации SSH"
add_failed "Ошибка конфигурации SSH"
return
fi
echo "Перезапуск SSH..."
systemctl restart ssh
echo "Проверка текущих параметров SSH..."
local ROOT PUB PASS
ROOT=$(sshd -T | awk '/permitrootlogin/{print $2}')
PUB=$(sshd -T | awk '/pubkeyauthentication/{print $2}')
PASS=$(sshd -T | awk '/passwordauthentication/{print $2}')
if [[ "$ROOT" == "prohibit-password" || "$ROOT" == "without-password" ]] &&
[[ "$PUB" == yes ]] &&
[[ "$PASS" == no ]]; then
add_success "SSH успешно сконфигурирован"
return
fi
echo
add_failed "Обнаружены конфликтующие параметры"
echo "Поиск и попытка исправления конфликтов..."
grep -HnE \
'^[[:space:]]*(PermitRootLogin|PasswordAuthentication|PubkeyAuthentication|UseDNS)' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null |
grep -v 99-hardening.conf || true
for FILE in /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf
do
[[ -f "$FILE" ]] || continue
[[ "$FILE" == "/etc/ssh/sshd_config.d/99-hardening.conf" ]] && continue
sed -i \
-e 's/^[[:space:]]*PermitRootLogin/#&/' \
-e 's/^[[:space:]]*PasswordAuthentication/#&/' \
-e 's/^[[:space:]]*PubkeyAuthentication/#&/' \
-e 's/^[[:space:]]*UseDNS/#&/' \
"$FILE"
done
echo "Проверка конфигурации SSH..."
if sshd -t; then
echo "Перезапуск SSH..."
systemctl restart ssh
echo "Конфликты исправлены"
add_success "Параметры SSH успешно настроены"
save_env "SSH settings have been successfully configured"
else
add_failed "Конфигурация SSH содержит ошибки"
save_env "SSH not configured"
pause
fi
}

configure_ssh() {
section "Смена порта SSH"
read_ports
echo "✓ Процедура выбора портов пройдена"
echo "Резервное копирование текущих настроек SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
mkdir -p /etc/ssh/sshd_config.d
cp -r /etc/ssh/sshd_config.d /etc/ssh/sshd_config.d.bak 2>/dev/null || true
echo "Запись нового SSH порта ${NPORT} в конфигурацию..."
sed -Ei \
"s/^[#[:space:]]*Port[[:space:]]+[0-9]+/Port ${NPORT}/" /etc/ssh/sshd_config
sed -i "s/^Port 22/Port ${NPORT}/" /etc/ssh/sshd_config 2>/dev/null || true
echo "Перезапуск systemctl..."
systemctl daemon-reload
if ! sshd -t; then
add_failed "Ошибка смены SSH порта"
echo "Восстановление изначальной конфигурации..."
cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
echo "Перезапуск SSH..."
systemctl restart ssh
add_failed "Порт SSH не изменен!"
return
fi
echo "Перезапуск SSH..."
systemctl restart ssh
sleep 2
echo "Проверка текущего SSH порта..."
if ss -ltn | grep -q ":${NPORT} "; then
add_success "SSH успешно переведен на порт ${NPORT}"
else
add_failed "SSH не слушает новый порт!"
return
fi
harden_ssh
save_env "New SSH port $NPORT successfully activated"
echo
echo "Новая команда подключения:"
echo "ssh -p ${NPORT} root@${IP}"
echo
echo "Можно скопировать ее и сохранить..."
}

configure_ssh_keys() {
section "Создание ключей SSH"
if ! confirm "Включить вход по ключу?"; then
return
fi
if [[ -n "${NPORT:-}" ]]; then
echo "Задаем имя ключа..."
read -rp "Имя ключа [id_ed25519]: " KEYNAME
KEYNAME=${KEYNAME:-id_ed25519}
echo
echo "На локальном ПК выполните:"
echo "ssh-keygen -t ed25519 -a 100 -f ~/.ssh/${KEYNAME}"
echo
read -rp "Вставьте публичный ключ: " PUBKEY
echo "Запись публичного ключа в файл..."
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "Активация публичного ключа..."
if grep -Fxq "$PUBKEY" ~/.ssh/authorized_keys; then
add_warning "Этот ключ уже существует"
else
echo "$PUBKEY" >> ~/.ssh/authorized_keys
add_success "Публичный ключ добавлен"
fi
chmod 600 ~/.ssh/authorized_keys
add_success "Ключи созданы"
save_env "SSH keys ${KEYNAME:-id_ed25519} successfully activated"
echo
echo "Новая команда подключения:"
echo "ssh -p ${NPORT} -i ~/.ssh/${KEYNAME} root@${IP}"
echo
echo "Можно скопировать ее и сохранить..."
else
echo "Сначало необходимо задать порты"
add_warning "NPORT не задан"
pause
fi
}

configure_fail2ban() {
section "Активация защиты от брутфорса"
if ! confirm "Включить Fail2Ban?"; then
return
fi
if [[ -n "${NPORT:-}" ]]; then
echo "Запуск Fail2Ban..."
systemctl enable --now fail2ban
echo "Конфигурация Fail2Ban для порта ${NPORT}..."
cat >/etc/fail2ban/jail.local <<EOF
[sshd]
enabled = true
port = ${NPORT}
maxretry = 3
bantime = 1h
findtime = 10m
EOF
echo "✓ Конфигурация выполнена"
echo "Перезапуск Fail2Ban..."
systemctl restart fail2ban
if systemctl is-active --quiet fail2ban
then
add_success "Fail2Ban активен"
save_env "Fail2Ban for port $NPORT successfully activated"
else
add_failed "Fail2Ban не запустился"
fi
else
echo "Сначало необходимо задать порты"
add_warning "NPORT не задан"
pause
fi
}

configure_ufw() {
section "Настройка фаервола"
if ! confirm "Включить UFW?"; then
return
fi
echo "Настройка портов..."
if [[ -n "${NPORT:-}" ]]; then
ufw limit "${NPORT}/tcp"
else
echo "Сначало необходимо задать порты"
add_warning "NPORT не задан. Правило UFW не добавлено"
fi
if [[ -n "${XPORT:-}" ]]; then
ufw allow "${XPORT}/tcp"
else
echo "Сначало необходимо задать порты"
add_warning "XPort не задан. Правило UFW не добавлено"
fi
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 443/udp
read -rp "Разрешить QUIC (8443/udp)? [y/N]: " QUIC
[[ "$QUIC" =~ ^[Yy]$ ]] && ufw allow 8443/udp
echo "Запрет остальных входящих соединений..."
ufw default deny incoming
echo "Разрешение для всех исходящих..."
ufw default allow outgoing
echo "Активация UFW..."
ufw --force enable
echo "Проверка статуса UFW..."
if ufw status | grep -q active
then
add_success "UFW успешно настроен и запущен"
save_env "UFW successfully activated"
ufw status verbose >> "$ENV_FILE"
else
add_failed "UFW не запущен"
ufw status verbose >> "$ENV_FILE"
fi
}

reset_ufw() {
section "Сброс параметров UFW"
if confirm "Сбросить текущую конфигурацию UFW?"; then
ufw --force reset
add_success "Конфигурация UFW сброшена"
fi
}

configure_kernel() {
section "Настройка ядра (BBR/sysctl)"
if ! confirm "Оптимизировать параметры sysctl?"; then
return
fi
echo "Активация BBR..."
echo "Оптимизация sysctl..."
declare -A SYSCTL
SYSCTL=(
["net.core.default_qdisc"]="fq"
["net.ipv4.tcp_congestion_control"]="bbr"
["net.ipv4.conf.all.rp_filter"]="1"
["net.ipv4.conf.default.rp_filter"]="1"
["net.ipv4.tcp_syncookies"]="1"
["net.ipv4.tcp_fastopen"]="3"
["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
["fs.file-max"]="1048576"
["net.core.somaxconn"]="4096"
)
for KEY in "${!SYSCTL[@]}"
do
VALUE=${SYSCTL[$KEY]}
if grep -q "^${KEY}" /etc/sysctl.conf
then
sed -i "s|^${KEY}.*|${KEY} = ${VALUE}|" /etc/sysctl.conf
else
echo "${KEY} = ${VALUE}" >> /etc/sysctl.conf
fi
done
add_success "BBR включен"
save_env "BBR activated"
configure_IPv6
}

configure_IPv6() {
section "Настройка IPv6"
if confirm "Отключить IPv6?"; then
sed -i \
    '/^[[:space:]]*net\.ipv6\.conf\.all\.disable_ipv6[[:space:]]*=/d;
     /^[[:space:]]*net\.ipv6\.conf\.default\.disable_ipv6[[:space:]]*=/d' \
    /etc/sysctl.conf
echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
add_success "IPv6 отключен"
save_env "IPv6 disabled"
else
add_warning "IPv6 остался активен"
save_env "IPv6 enabled"
fi
echo "Чтение новых параметров sysctl.conf..."
sysctl -p
add_success "sysctl.conf настроен"
save_env "sysctl.conf successfully configured"
}

configure_timezone() {
section "Часовой пояс"
if ! confirm "Настроить часовой пояс?"; then
return
fi
read -rp "Введите часовой пояс, например Europe/City: " TIMEZONE
[[ -z "$TIMEZONE" ]] && return
echo "Установка часового пояса..."
timedatectl set-timezone "$TIMEZONE"
save_env "Timezone: $TIMEZONE"
add_success "Часовой пояс задан как $TIMEZONE"
}

configure_updates() {
section "Автоматические обновления"
if ! confirm "Настроить автообновления?"; then
return
fi
echo "Конфигурация Unattended Upgrades..."
dpkg-reconfigure --priority=low unattended-upgrades
if systemctl is-active --quiet unattended-upgrades
then
add_success "Unattended Upgrades активирован"
save_env "Unattended Upgrades successfully activated"
else
add_failed "Unattended Upgrades не запущен"
save_env "Unattended Upgrades not activ"
fi
}

check_ssh_security() {
section "Проверка конфигурации"
local SSH_PORT
local F2B_PORT
local UFW_RULE
# Get real SSH port
if ! SSH_PORT=$(sshd -T | grep '^port ' | awk '{print $2}'); then
add_failed "Не удалось определить порт SSH"
return
fi
# Get real Fail2Ban port for jail sshd
F2B_PORT=$(awk -F '=' '
/^[[:space:]]*port[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2)
print $2
exit}
' /etc/fail2ban/jail.local)
# Chek UFW port
UFW_RULE=$(ufw status | grep -E "^${SSH_PORT}/tcp" || true)
echo "SSH порт:       $SSH_PORT"
echo "Fail2Ban порт:  $F2B_PORT"
echo "UFW правило:    $UFW_RULE"
if [[ "$SSH_PORT" == "$F2B_PORT" ]]; then
add_success "Порт SSH и Fail2Ban совпадают"
else
add_failed "Порт SSH и Fail2Ban не совпадают"
pause
fi
if [[ -n "$UFW_RULE" ]]; then
add_success "SSH порт открыт в UFW"
else
add_failed "SSH порт не открыт в UFW"
pause
fi
}

true_info() {
local SSH_PORT F2B_PORT UFW_RULE ROOT PUB PASS UPDATES
source /etc/os-release
echo "Script version: $SVERSION"
echo "OS: $PRETTY_NAME Like $ID_LIKE"
echo "Code name: $VERSION_CODENAME"
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"
IP=$(curl -4 -fsSL ifconfig.me || echo "unknown")
echo "IP: $IP"
RAM=$(free -h | awk '/^Mem:/ {print $2}')
echo "RAM: $RAM"
echo "Created: $(date)"
TIMEZONE=$(timedatectl show -p Timezone --value)
echo "Timezone: $TIMEZONE"
if [[ -z "${NEW_PASS:-}" ]]; then
echo "Root password not set in this session"
else
echo "Root password: ${NEW_PASS:-}"
fi
if command -v sshd &>/dev/null; then
echo "OpenSSH server is present"
else
echo "OpenSSH server is not installed"
echo "Please install it first"
pause
fi
if [[ -f /var/run/reboot-required ]]; then
echo "The server needs a reboot"
else
echo "Reboot not required"
fi
if ! sshd -t; then
echo "SSH configuration is invalid"
else
echo "SSH configuration is valid"
fi
ROOT=$(sshd -T | awk '/permitrootlogin/{print $2}')
PUB=$(sshd -T | awk '/pubkeyauthentication/{print $2}')
PASS=$(sshd -T | awk '/passwordauthentication/{print $2}')
echo "PermitRootLogin $ROOT"
echo "PubkeyAuthentication $PUB"
echo "PasswordAuthentication $PASS"
if [[ "$ROOT" == "prohibit-password" || "$ROOT" == "without-password" ]] &&
[[ "$PUB" == yes ]] &&
[[ "$PASS" == no ]]; then
echo "SSH configured successfully"
echo "Root can login only using SSH key"
fi
if [[ -f ~/.ssh/authorized_keys ]]; then
echo "File 'authorized_keys' present"
else
echo "File 'authorized_keys' not present"
fi
if [[ -z "${XPORT:-}" ]]; then
echo "Addons port not set in this session"
else
echo "Addons port: ${XPORT}"
fi
if apt-get update -qq; then
echo "Package lists updated"
else
echo "Failed to update package lists"
fi
UPDATES=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')
if (( UPDATES > 0 )); then
echo "Updates available: $UPDATES"
else
echo "System is up to date"
fi
PACKAGES=(
curl
wget
git
nano
mc
htop
btop
jq
dnsutils
net-tools
ca-certificates
gnupg
lsb-release
golang-go
certbot
chrony
ufw
fail2ban
unattended-upgrades
)
MISSING=()
for PACKAGE in "${PACKAGES[@]}"; do
if ! dpkg -s "$PACKAGE" &>/dev/null; then
MISSING+=("$PACKAGE")
fi
done
if (( ${#MISSING[@]} == 0 )); then
echo "All necessary packages are installed"
else
echo "Missing packages:"
printf '   %s\n' "${MISSING[@]}"
fi
if systemctl is-active --quiet fail2ban; then
echo "Fail2Ban is active"
else
echo "Fail2Ban not active"
fi
if ufw status | grep -q active
then
echo "UFW is active"
ufw status verbose
else
echo "UFW not active"
ufw status verbose
fi
if [[ "$(sysctl -n net.ipv4.tcp_congestion_control)" == "bbr" ]]; then
echo "BBR is on"
else
echo "BBR is off"
fi
if [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6)" == "1" ]] &&
[[ "$(sysctl -n net.ipv6.conf.default.disable_ipv6)" == "1" ]]; then
echo "IPv6 is off"
else
echo "IPv6 is on"
fi
if systemctl is-active --quiet unattended-upgrades
then
echo "Unattended Upgrades successfully activated"
else
echo "Unattended Upgrades not active"
fi
# Get real SSH port
SSH_PORT=$(sshd -T | awk '$1 == "port" {print $2; exit}')
if [[ -z "$SSH_PORT" ]]; then
echo "SSH port not detected"
fi
# Get real Fail2Ban port for jail sshd
if [[ -f /etc/fail2ban/jail.local ]]; then
F2B_PORT=$(awk -F '=' '
/^[[:space:]]*port[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2)
print $2
exit}
' /etc/fail2ban/jail.local)
else
F2B_PORT="not configured"
fi
# Check UFW port
UFW_RULE=$(ufw status | grep -E "^${SSH_PORT}/tcp" || true)
echo "SSH port:       $SSH_PORT"
echo "Fail2Ban port:  $F2B_PORT"
echo "UFW rule:       $UFW_RULE"
if [[ "$F2B_PORT" == "ssh" || "$F2B_PORT" == "sshd" || "$SSH_PORT" == "$F2B_PORT" ]]; then
echo "SSH and Fail2Ban ports match"
else
echo "SSH and Fail2Ban ports do not match"
fi
if [[ -n "$UFW_RULE" ]]; then
echo "SSH port is open in UFW"
else
echo "SSH port not open in UFW"
fi
}

# Full setup
full_setup() {
change_root_password
update_system
install_packages
configure_ssh
configure_ssh_keys
configure_fail2ban
configure_ufw
configure_kernel
configure_timezone
configure_updates
check_ssh_security
show_info
}

# Main menu
declare -A ACTIONS=(
[1]=full_setup
[2]=change_root_password
[3]=update_system
[4]=install_packages
[5]=configure_ssh
[5a]=read_ports
[5b]=harden_ssh
[6]=configure_ssh_keys
[7]=configure_fail2ban
[8]=configure_ufw
[8a]=reset_ufw
[9]=configure_kernel
[9a]=configure_IPv6
[10]=configure_timezone
[11]=configure_updates
[12]=check_ssh_security
[13]=show_info
[14]=true_info
[15]=update_script
[16]=reboot_server
)

main_menu() {
while true
do
clear
echo "========= VPS_SetUp v$SVERSION ========="
echo
echo "1.  Полная настройка сервера"
echo
echo "2.  Смена пароля root"
echo "3.  Обновление системы"
echo "4.  Установка часто используемых пакетов"
echo "5.  Настройка параметров SSH"
echo "5a. Задать порты"
echo "5b. Ужесточение параметров SSH"
echo "6.  Установка SSH-ключей"
echo "7.  Настройка Fail2Ban"
echo "8.  Настройка UFW"
echo "8a. Сброс текущих настроек UFW"
echo "9.  Настройка ядра (BBR/sysctl)"
echo "9a. Настройка IPv6"
echo "10. Установка часового пояса"
echo "11. Активация автообновлений"
echo "12. Проверка конфигурации"
echo "13. Показать выполненные изменения"
echo "14. Показать текущую конфигурацию"
echo "15. Обновить скрипт"
echo "16. Перезагрузить сервер"
echo
echo "0. Выход"
echo
echo "Можно выбрать несколько пунктов через пробел."
echo "Например: 12 4 7 8"
echo
read -rp "Выберите пункт(ы): " MENU
for ITEM in $MENU
do
if [[ "$ITEM" == "0" ]]; then
clear
exit 0
fi
if [[ -v ACTIONS[$ITEM] ]]; then
"${ACTIONS[$ITEM]}"
else
echo "Неизвестный пункт: $ITEM"
fi
done
echo
read -n1 -rsp "Нажмите любую клавишу для возврата в меню..."
done
}

TUI_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Полная настройка сервера"
"Смена пароля root"
"Обновление системы"
"Установка часто используемых пакетов"
"Настройка F2B/Time/UU"
"Настройка параметров SSH"
"Настройка UFW"
"Настройка ядра"
"Проверки"
"Обновить скрипт"
"Перезагрузить сервер"
"Выход"
)
while true; do
clear
echo "========= VPS_SetUp v$SVERSION ========="
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
echo
echo "↑↓ - Навигация   Enter - Выбор   Q - Выход"
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) full_setup ;;
1) change_root_password ;;
2) update_system ;;
3) install_packages ;;
4) utils_menu ;;
5) ssh_menu ;;
6) ufw_menu ;;
7) kernel_menu ;;
8) test_menu ;;
9) update_script ;;
10) reboot_server ;;
11) exit 0 ;;
esac
;;
q|Q)
exit 0
;;
esac
(( SELECTED < 0 )) && SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) && SELECTED=0
done
}

utils_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Настройка Fail2Ban"
"Установка часового пояса"
"Активация автообновлений"
"Назад"
)
while true; do
clear
echo "======== Настройка  F2B/Time/UU ========"
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) configure_fail2ban ;;
1) configure_timezone ;;
2) configure_updates ;;
3) return ;;
esac
;;
q|Q)
return
;;
esac
(( SELECTED < 0 )) &&
SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) &&
SELECTED=0
done
}

ssh_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Полная настройка SSH"
"Задать порты"
"Ужесточение параметров SSH"
"Установка SSH-ключей"
"Назад"
)
while true; do
clear
echo "======= Настройка параметров SSH ======="
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) configure_ssh ;;
1) read_ports ;;
2) harden_ssh ;;
3) configure_ssh_keys ;;
4) return ;;
esac
;;
q|Q)
return
;;
esac
(( SELECTED < 0 )) &&
SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) &&
SELECTED=0
done
}

ufw_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Включение UFW"
"Сброс текущих настроек UFW"
"Назад"
)
while true; do
clear
echo "============ Настройка  UFW ============"
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) configure_ufw ;;
1) reset_ufw ;;
2) return ;;
esac
;;
q|Q)
return
;;
esac
(( SELECTED < 0 )) &&
SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) &&
SELECTED=0
done
}

kernel_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Настройка (BBR/sysctl)"
"Настройка IPv6"
"Назад"
)
while true; do
clear
echo "============ Настройка ядра ============"
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) configure_kernel ;;
1) configure_IPv6 ;;
2) return ;;
esac
;;
q|Q)
return
;;
esac
(( SELECTED < 0 )) &&
SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) &&
SELECTED=0
done
}

test_menu() {
local SELECTED=0
local KEY
local MENU_ITEMS=(
"Проверка конфигурации портов"
"Показать изменения этой сессии"
"Показать текущую конфигурацию"
"Назад"
)
while true; do
clear
echo "=============== Проверки ==============="
for ((i=0; i<${#MENU_ITEMS[@]}; i++)); do
if (( i == SELECTED )); then
echo -e "\e[7m> ${MENU_ITEMS[$i]}\e[0m"
else
echo "  ${MENU_ITEMS[$i]}"
fi
done
read -rsn1 KEY
case "$KEY" in
$'\x1b')
read -rsn2 KEY
case "$KEY" in
'[A')
((SELECTED--))
;;
'[B')
((SELECTED++))
;;
esac
;;
'')
case "$SELECTED" in
0) check_ssh_security ;;
1) show_info ;;
2) true_info ;;
3) return ;;
esac
;;
q|Q)
return
;;
esac
(( SELECTED < 0 )) &&
SELECTED=$((${#MENU_ITEMS[@]} - 1))
(( SELECTED >= ${#MENU_ITEMS[@]} )) &&
SELECTED=0
done
}

menu_choice() {
section "Выбор типа меню"
if confirm "Использовать TUI?"; then
TUI_menu
else
main_menu
fi
}

# Start scripts
init_server_env
menu_choice
