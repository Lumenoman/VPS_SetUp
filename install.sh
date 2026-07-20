install_script() {
mkdir -p /usr/local/bin/VPS_SetUp
curl -fsSL \
https://raw.githubusercontent.com/Lumenoman/VPS_SetUp/main/VPS_SetUp.sh \
-o /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
chmod +x /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
ln -s /usr/local/bin/VPS_SetUp/VPS_SetUp.sh /usr/local/bin/VPS_SetUp
echo "✓ VPS_SetUp установлен"
echo "Запуск:"
echo "VPS_SetUp"
}
