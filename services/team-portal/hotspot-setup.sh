#!/usr/bin/env bash
# Script para configurar el Punto de Acceso Wi-Fi (Hotspot) en Raspberry Pi OS Bookworm usando NetworkManager
set -e

SSID="${HOTSPOT_SSID:-RPi5-TeamNetwork}"
PASSWORD="${HOTSPOT_PASSWORD:-TeamWorkSecure2026}"
HOTSPOT_IP="${HOTSPOT_GATEWAY_IP:-192.168.4.1/24}"

echo "=== Configurando Punto de Acceso Wi-Fi: $SSID ==="

# Verificar que se ejecute con permisos sudo
if [ "$EUID" -ne 0 ]; then
  echo "Por favor ejecuta este script con sudo: sudo ./hotspot-setup.sh"
  exit 1
fi

# Eliminar conexion previa si existe
nmcli connection delete "RPi-Team-Hotspot" 2>/dev/null || true

# Crear punto de acceso Wi-Fi
nmcli con add type wifi ifname wlan0 con-name "RPi-Team-Hotspot" autoconnect yes ssid "$SSID"
nmcli con modify "RPi-Team-Hotspot" 802-11-wireless.mode ap 802-11-wireless.band bg
nmcli con modify "RPi-Team-Hotspot" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$PASSWORD"
nmcli con modify "RPi-Team-Hotspot" ipv4.method shared ipv4.addresses "$HOTSPOT_IP"

# Levantar la conexion
nmcli con up "RPi-Team-Hotspot"

echo "[OK] Punto de Acceso Wi-Fi activado con exito."
echo "SSID: $SSID"
echo "IP Gateway: 192.168.4.1"
