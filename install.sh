install_script() {
mkdir -p /usr/local/bin/VPS_SetUp
curl -fsSL \
https://raw.githubusercontent.com/Lumenoman/VPS_SetUp/main/VPS_SetUp.sh \
-o /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
chmod +x /usr/local/bin/VPS_SetUp/VPS_SetUp.sh
ln -sf /usr/local/bin/VPS_SetUp/VPS_SetUp.sh /usr/local/bin/VPSSetUp
echo "✓ VPS_SetUp.sh установлен/обновлен"
echo "Запуск:"
echo "VPSSetUp"
}
install_script
