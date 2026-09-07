#!/usr/bin/env bash
# Configuracion del Firewall UFW optimizado para Tailscale, Red Local y Contenedores
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Por favor ejecuta este script con sudo: sudo ./security/ufw-rules.sh"
  exit 1
fi

echo "=== Configurando UFW Firewall ==="

if ! command -v ufw >/dev/null 2>&1; then
  apt-get update && apt-get install -y ufw
fi

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

# Permitir trafico en interfaz Tailscale cifrada
ufw allow in on tailscale0 comment 'Permitir todo desde Tailscale'

# Permitir trafico de loopback
ufw allow in on lo comment 'Permitir loopback local'

# Permitir SSH local
ufw allow 22/tcp comment 'SSH local'

# Permitir puertos de Punto de Acceso y servicios
ufw allow in on wlan0 to any port 8080 proto tcp comment 'Portal Web Hotspot'
ufw allow in on wlan0 to any port 3000 proto tcp comment 'PairDrop Webshare Hotspot'
ufw allow in on wlan0 to any port 53317 proto tcp comment 'LocalSend TCP'
ufw allow in on wlan0 to any port 53317 proto udp comment 'LocalSend UDP Discovery'
ufw allow in on wlan0 to any port 53 comment 'DNS Hotspot'
ufw allow in on wlan0 to any port 67 proto udp comment 'DHCP Hotspot'

ufw --force enable
ufw status verbose

echo "[OK] Firewall configurado y activo."
