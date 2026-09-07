#!/usr/bin/env bash
# ==============================================================================
# INSTALADOR Y ORQUESTADOR DE NUBE HOMELAB
# Compatible con: ARM64 (Raspberry Pi 5) y x86_64 (Lenovo ThinkCentre / Mini PC)
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Paleta de colores ANSI
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_DIM='\033[2m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_MAGENTA='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[1;37m'

ENV_FILE="$SCRIPT_DIR/.env"
ENV_EXAMPLE="$SCRIPT_DIR/.env.example"

# Inicializar .env si no existe
if [ ! -f "$ENV_FILE" ]; then
  if [ -f "$ENV_EXAMPLE" ]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
  else
    touch "$ENV_FILE"
  fi
fi

# Cargar variables actuales
set -a
source "$ENV_FILE" 2>/dev/null || true
set +a

# Deteccion automatica de arquitectura
SYS_ARCH=$(uname -m)
case "$SYS_ARCH" in
  aarch64|arm64)
    DETECTED_ARCH="ARM64"
    DEFAULT_PROFILE="RPi 5"
    ;;
  x86_64|amd64)
    DETECTED_ARCH="x86_64"
    DEFAULT_PROFILE="ThinkCentre / PC"
    ;;
  *)
    DETECTED_ARCH="$SYS_ARCH"
    DEFAULT_PROFILE="Generico"
    ;;
esac

TARGET_ARCH="${TARGET_ARCH:-$DETECTED_ARCH}"

# Variables de perfil segun arquitectura
if [ "$TARGET_ARCH" = "ARM64" ]; then
  DEFAULT_THREADS=4
  DEFAULT_RAM="4G"
else
  DEFAULT_THREADS=8
  DEFAULT_RAM="8G"
fi

INSTALL_DOCKER=${INSTALL_DOCKER:-1}
INSTALL_TAILSCALE=${INSTALL_TAILSCALE:-1}
INSTALL_SECURITY=${INSTALL_SECURITY:-1}
MANAGEMENT_TOOL=${MANAGEMENT_TOOL:-"dockge"}
ENABLE_HOTSPOT=${ENABLE_HOTSPOT:-1}

ENABLE_OBSIDIAN=${ENABLE_OBSIDIAN:-1}
ENABLE_CICD=${ENABLE_CICD:-0}
ENABLE_NETWORK=${ENABLE_NETWORK:-1}
ENABLE_AI_SANDBOX=${ENABLE_AI_SANDBOX:-0}

HOTSPOT_SSID="${HOTSPOT_SSID:-RPi5-TeamNetwork}"
HOTSPOT_PASSWORD="${HOTSPOT_PASSWORD:-TeamWorkSecure2026}"
HOTSPOT_GATEWAY_IP="${HOTSPOT_GATEWAY_IP:-192.168.4.1/24}"
PORTAL_PORT="${PORTAL_PORT:-8080}"
PORTAL_ACCESS_PASSWORD="${PORTAL_ACCESS_PASSWORD:-TeamAccess2026}"
PAIRDROP_PORT="${PAIRDROP_PORT:-3000}"

COUCHDB_PORT="${COUCHDB_PORT:-5984}"
COUCHDB_USER="${COUCHDB_USER:-admin}"
COUCHDB_PASSWORD="${COUCHDB_PASSWORD:-ObsidianPass2026!}"

DOCKGE_PORT="${DOCKGE_PORT:-5001}"
GITEA_HTTP_PORT="${GITEA_HTTP_PORT:-3001}"
GITEA_SSH_PORT="${GITEA_SSH_PORT:-2222}"
JENKINS_PORT="${JENKINS_PORT:-8081}"

PIHOLE_WEB_PORT="${PIHOLE_WEB_PORT:-8082}"
PIHOLE_PASSWORD="${PIHOLE_PASSWORD:-AdminPihole2026!}"

AI_PORT="${AI_PORT:-8000}"
LLAMA_MODEL_FILE="${LLAMA_MODEL_FILE:-LFM2.5-2.6B-Q_4_K_M.gguf}"
LLAMA_THREADS="${LLAMA_THREADS:-$DEFAULT_THREADS}"
LLAMA_MAX_RAM="${LLAMA_MAX_RAM:-$DEFAULT_RAM}"

PRIVATE_BIND_IP="${PRIVATE_BIND_IP:-127.0.0.1}"
TAILSCALE_AUTHKEY="${TAILSCALE_AUTHKEY:-}"

detect_wifi_iface() {
  local iface=""
  if command -v nmcli >/dev/null 2>&1; then
    iface=$(nmcli device status 2>/dev/null | awk '$2=="wifi" {print $1; exit}')
  fi
  if [ -z "$iface" ] && [ -d /sys/class/net ]; then
    for d in /sys/class/net/*; do
      if [ -d "$d/wireless" ] || [ -e "$d/phy80211" ]; then
        iface=$(basename "$d")
        break
      fi
    done
  fi
  echo "$iface"
}

WIFI_IFACE=$(detect_wifi_iface)
WIFI_IFACE="${WIFI_IFACE:-wlan0}"

save_env() {
  {
    echo "# Configuracion generada por Despliegue de Nube Installer"
    echo "TARGET_ARCH=\"$TARGET_ARCH\""
    echo "INSTALL_DOCKER=$INSTALL_DOCKER"
    echo "INSTALL_TAILSCALE=$INSTALL_TAILSCALE"
    echo "INSTALL_SECURITY=$INSTALL_SECURITY"
    echo "MANAGEMENT_TOOL=\"$MANAGEMENT_TOOL\""
    echo "ENABLE_HOTSPOT=$ENABLE_HOTSPOT"
    echo ""
    echo "ENABLE_OBSIDIAN=$ENABLE_OBSIDIAN"
    echo "ENABLE_CICD=$ENABLE_CICD"
    echo "ENABLE_NETWORK=$ENABLE_NETWORK"
    echo "ENABLE_AI_SANDBOX=$ENABLE_AI_SANDBOX"
    echo ""
    echo "# Wi-Fi Hotspot y Portal"
    echo "WIFI_IFACE=\"$WIFI_IFACE\""
    echo "HOTSPOT_SSID=\"$HOTSPOT_SSID\""
    echo "HOTSPOT_PASSWORD=\"$HOTSPOT_PASSWORD\""
    echo "HOTSPOT_GATEWAY_IP=\"$HOTSPOT_GATEWAY_IP\""
    echo "PORTAL_PORT=$PORTAL_PORT"
    echo "PORTAL_ACCESS_PASSWORD=\"$PORTAL_ACCESS_PASSWORD\""
    echo "PAIRDROP_PORT=$PAIRDROP_PORT"
    echo ""
    echo "# Aislamiento de puertos"
    echo "PRIVATE_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo ""
    echo "# CouchDB LiveSync"
    echo "COUCHDB_PORT=$COUCHDB_PORT"
    echo "COUCHDB_USER=\"$COUCHDB_USER\""
    echo "COUCHDB_PASSWORD=\"$COUCHDB_PASSWORD\""
    echo "OBSIDIAN_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo ""
    echo "# Gestores Web"
    echo "DOCKGE_PORT=$DOCKGE_PORT"
    echo "MANAGEMENT_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo ""
    echo "# CI/CD"
    echo "GITEA_HTTP_PORT=$GITEA_HTTP_PORT"
    echo "GITEA_SSH_PORT=$GITEA_SSH_PORT"
    echo "GITEA_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo "JENKINS_PORT=$JENKINS_PORT"
    echo "JENKINS_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo ""
    echo "# Pi-hole"
    echo "PIHOLE_WEB_PORT=$PIHOLE_WEB_PORT"
    echo "PIHOLE_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo "PIHOLE_PASSWORD=\"$PIHOLE_PASSWORD\""
    echo ""
    echo "# Asistente IA"
    echo "AI_PORT=$AI_PORT"
    echo "AI_BIND_IP=\"$PRIVATE_BIND_IP\""
    echo "LLAMA_MODEL_FILE=\"$LLAMA_MODEL_FILE\""
    echo "LLAMA_THREADS=$LLAMA_THREADS"
    echo "LLAMA_MAX_RAM=\"$LLAMA_MAX_RAM\""
    echo ""
    echo "# Tailscale"
    echo "TAILSCALE_AUTHKEY=\"$TAILSCALE_AUTHKEY\""
  } > "$ENV_FILE"
}

print_header() {
  clear
  echo -e "${C_CYAN}+------------------------------------------------------------------------+${C_RESET}"
  echo -e "${C_CYAN}|${C_BOLD}${C_WHITE}   INSTALADOR Y ORQUESTADOR DE NUBE HOMELAB                             ${C_CYAN}|${C_RESET}"
  echo -e "${C_CYAN}|${C_DIM}   Instalacion Modular de Cero a Produccion (Docker, Tailscale, Apps)   ${C_CYAN}|${C_RESET}"
  echo -e "${C_CYAN}+------------------------------------------------------------------------+${C_RESET}"
  
  local TS_IP
  TS_IP=$(tailscale ip -4 2>/dev/null || echo "No conectado")
  local DOCKER_STAT
  command -v docker >/dev/null 2>&1 && DOCKER_STAT="${C_GREEN}Instalado${C_RESET}" || DOCKER_STAT="${C_RED}No instalado${C_RESET}"
  
  echo -e " ${C_DIM}Arquitectura Objetivo:${C_RESET} ${C_YELLOW}${TARGET_ARCH}${C_RESET} | ${C_DIM}Docker:${C_RESET} $DOCKER_STAT | ${C_DIM}Tailscale:${C_RESET} ${C_CYAN}${TS_IP}${C_RESET}"
  echo -e "${C_CYAN}--------------------------------------------------------------------------${C_RESET}"
}

pause() {
  echo -e "\n${C_DIM}Presiona ${C_WHITE}[Enter]${C_RESET}${C_DIM} para continuar...${C_RESET}"
  read -r
}

menu_architecture() {
  print_header
  echo -e "${C_BOLD}[SECCION 1] SELECCION DE ARQUITECTURA OBJETIVO${C_RESET}\n"
  echo -e " Arquitectura detectada automaticamente por el kernel: ${C_YELLOW}$SYS_ARCH${C_RESET}"
  echo ""
  echo -e "  ${C_WHITE}1)${C_RESET} ARM64 (Raspberry Pi 5 / Odroid / Ampere)"
  echo -e "     - Optimizado para 4 hilos de CPU Cortex-A76"
  echo -e "     - Limite termico y memoria para 16GB RAM"
  echo ""
  echo -e "  ${C_WHITE}2)${C_RESET} x86_64 / AMD64 (Lenovo ThinkCentre / Intel NUC / Mini PC)"
  echo -e "     - Optimizado para 8+ hilos x86_64 AVX2"
  echo -e "     - Asignacion de hasta 8GB+ de RAM para modelos y microservicios"
  echo ""
  echo -ne "${C_BOLD}Selecciona la arquitectura deseada (1 o 2) [Actual: $TARGET_ARCH]: ${C_RESET}"
  read -r arch_choice

  if [ "$arch_choice" = "1" ]; then
    TARGET_ARCH="ARM64"
    LLAMA_THREADS=4
    LLAMA_MAX_RAM="4G"
    echo -e "\n${C_GREEN}[OK] Arquitectura configurada en ARM64 (Raspberry Pi 5).${C_RESET}"
  elif [ "$arch_choice" = "2" ]; then
    TARGET_ARCH="x86_64"
    LLAMA_THREADS=8
    LLAMA_MAX_RAM="8G"
    echo -e "\n${C_GREEN}[OK] Arquitectura configurada en x86_64 (ThinkCentre / PC).${C_RESET}"
  fi
  save_env
  pause
}

install_system_deps() {
  echo -e "${C_CYAN}==> [Sistema] Actualizando repositorios e instalando herramientas base...${C_RESET}"
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y curl wget git ufw fail2ban python3 python3-pip htop network-manager
  elif command -v dnf >/dev/null 2>&1; then
    sudo dnf install -y curl wget git ufw fail2ban python3 htop NetworkManager
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -Sy --noconfirm curl wget git ufw fail2ban python htop networkmanager
  fi
  echo -e "${C_GREEN}[OK] Paquetes esenciales del sistema instalados.${C_RESET}"
}

install_docker_engine() {
  print_header
  echo -e "${C_BOLD}[SECCION 2] INSTALACION DE DOCKER ENGINE Y DOCKER COMPOSE${C_RESET}\n"
  
  if command -v docker >/dev/null 2>&1; then
    echo -e "${C_GREEN}[OK] Docker ya se encuentra instalado:${C_RESET} $(docker --version)"
    echo -e "${C_GREEN}[OK] Compose:${C_RESET} $(docker compose version 2>/dev/null || echo 'plugin detectado')"
    echo -e "\nDeseas reinstalar o actualizar Docker? (s/N): "
    read -r re_doc
    if [[ ! "$re_doc" =~ ^[sS]$ ]]; then
      pause
      return
    fi
  fi

  echo -e "\n${C_CYAN}Descargando e instalando Docker oficial multi-arquitectura (${TARGET_ARCH})...${C_RESET}"
  curl -fsSL https://get.docker.com | sudo sh

  echo -e "\n${C_CYAN}Anadiendo usuario actual ($USER) al grupo docker...${C_RESET}"
  sudo usermod -aG docker "$USER" 2>/dev/null || true

  echo -e "\n${C_CYAN}Habilitando Docker en el arranque de la maquina (systemd)...${C_RESET}"
  sudo systemctl enable docker
  sudo systemctl start docker

  echo -e "\n${C_GREEN}[OK] Docker Engine y Docker Compose instalados y activos.${C_RESET}"
  pause
}

install_tailscale_vpn() {
  print_header
  echo -e "${C_BOLD}[SECCION 3] INSTALACION Y CONFIGURACION DE TAILSCALE${C_RESET}\n"

  if ! command -v tailscale >/dev/null 2>&1; then
    echo -e "${C_CYAN}Descargando e instalando cliente oficial de Tailscale...${C_RESET}"
    curl -fsSL https://tailscale.com/install.sh | sudo sh
    sudo systemctl enable tailscaled
    sudo systemctl start tailscaled
  else
    echo -e "${C_GREEN}[OK] Tailscale ya se encuentra instalado.${C_RESET}"
  fi

  echo -e "\n${C_BOLD}Autenticacion del Nodo en tu Tailnet:${C_RESET}"
  if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo -e "Usando Auth Key preconfigurada..."
    sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
  else
    echo -e "Ingresa una Auth Key (dejar en blanco para autenticar por navegador): "
    read -r user_key
    if [ -n "$user_key" ]; then
      TAILSCALE_AUTHKEY="$user_key"
      save_env
      sudo tailscale up --authkey="$TAILSCALE_AUTHKEY" --ssh
    else
      echo -e "\n${C_YELLOW}Abre el siguiente enlace en tu navegador para autorizar la maquina:${C_RESET}"
      sudo tailscale up --ssh || true
    fi
  fi

  echo -e "\n${C_GREEN}[OK] Tailscale configurado con soporte Tailscale SSH.${C_RESET}"
  pause
}

install_management_dashboard() {
  print_header
  echo -e "${C_BOLD}[SECCION 4] INSTALACION DEL GESTOR WEB (LAPTOPS / NAVEGADOR)${C_RESET}\n"
  echo -e " Elige la interfaz web que deseas para controlar los contenedores desde tu laptop:"
  echo ""
  echo -e "  ${C_WHITE}1)${C_RESET} ${C_GREEN}Dockge (Recomendado para Homelabs modulares)${C_RESET}"
  echo -e "     - Ultraligero, corre en Docker en puerto ${DOCKGE_PORT}."
  echo -e "     - Editor visual de Compose, visualizacion de logs en vivo."
  echo ""
  echo -e "  ${C_WHITE}2)${C_RESET} ${C_CYAN}CasaOS (Panel tipo Escritorio / App Store)${C_RESET}"
  echo -e "     - Sistema web intuitivo con gestion de almacenamiento."
  echo -e "     - Instalacion nativa mediante el script oficial de CasaOS."
  echo ""
  echo -e "  ${C_WHITE}3)${C_RESET} ${C_YELLOW}Ambos (Dockge + CasaOS)${C_RESET}"
  echo -e "     - CasaOS como dashboard general y Dockge para stacks de Compose."
  echo ""
  echo -e "  ${C_WHITE}4)${C_RESET} Ninguno (Solo ServerBox en movil / CLI)"
  echo ""
  echo -ne "${C_BOLD}Elige una opcion (1-4) [Actual: $MANAGEMENT_TOOL]: ${C_RESET}"
  read -r mgmt_choice

  case "$mgmt_choice" in
    1)
      MANAGEMENT_TOOL="dockge"
      echo -e "\n${C_CYAN}Desplegando Dockge...${C_RESET}"
      (cd services/management && docker compose up -d)
      echo -e "${C_GREEN}[OK] Dockge activo en puerto ${DOCKGE_PORT}.${C_RESET}"
      ;;
    2)
      MANAGEMENT_TOOL="casaos"
      echo -e "\n${C_CYAN}Instalando CasaOS de forma nativa...${C_RESET}"
      curl -fsSL https://get.casaos.io | sudo bash
      echo -e "${C_GREEN}[OK] CasaOS instalado.${C_RESET}"
      ;;
    3)
      MANAGEMENT_TOOL="both"
      echo -e "\n${C_CYAN}Instalando CasaOS y levantando Dockge...${C_RESET}"
      curl -fsSL https://get.casaos.io | sudo bash
      (cd services/management && docker compose up -d)
      echo -e "${C_GREEN}[OK] Ambos gestores activos.${C_RESET}"
      ;;
    4)
      MANAGEMENT_TOOL="none"
      (cd services/management && docker compose down 2>/dev/null || true)
      echo -e "${C_YELLOW}Gestores web desactivados.${C_RESET}"
      ;;
  esac
  save_env
  pause
}

setup_security_firewall() {
  print_header
  echo -e "${C_BOLD}[SECCION 5] CONFIGURACION DE SEGURIDAD, FIREWALL Y FAIL2BAN${C_RESET}\n"

  echo -e "${C_CYAN}Aplicando reglas de firewall UFW...${C_RESET}"
  sudo bash security/ufw-rules.sh

  echo -e "\n${C_CYAN}Configurando Fail2Ban contra ataques de fuerza bruta...${C_RESET}"
  sudo cp security/fail2ban/jail.local /etc/fail2ban/jail.local
  sudo systemctl restart fail2ban 2>/dev/null || sudo systemctl restart fail2ban.service 2>/dev/null || true

  echo -e "\n${C_GREEN}[OK] Firewall UFW y Fail2Ban activados y configurados.${C_RESET}"
  pause
}

setup_hotspot_portal() {
  print_header
  echo -e "${C_BOLD}[SECCION 6] PUNTO DE ACCESO WI-FI Y PORTAL LOCALSEND / PAIRDROP${C_RESET}\n"
  
  local wifi_detected
  wifi_detected=$(detect_wifi_iface)
  
  if [ -z "$wifi_detected" ]; then
    echo -e "${C_YELLOW}[AVISO] No se detecto ninguna interfaz Wi-Fi activa.${C_RESET}"
    echo -e " PairDrop y el Portal Web se desplegaran para la red local cableada o Tailscale."
    ENABLE_HOTSPOT=0
  else
    echo -e " Interfaz inalambrica detectada: ${C_GREEN}$wifi_detected${C_RESET}"
    echo -e " Deseas emitir la red Wi-Fi autonoma para tu equipo de trabajo? (S/n): "
    read -r resp
    if [[ "$resp" =~ ^[nN]$ ]]; then
      ENABLE_HOTSPOT=0
    else
      ENABLE_HOTSPOT=1
      WIFI_IFACE="$wifi_detected"
      echo -e "\nNombre de red SSID [Actual: $HOTSPOT_SSID]:"
      read -r val && [ -n "$val" ] && HOTSPOT_SSID="$val"
      echo -e "Contrasena WPA2 [Actual: $HOTSPOT_PASSWORD]:"
      read -r val && [ -n "$val" ] && HOTSPOT_PASSWORD="$val"
      echo -e "Contrasena del Portal Web [Actual: $PORTAL_ACCESS_PASSWORD]:"
      read -r val && [ -n "$val" ] && PORTAL_ACCESS_PASSWORD="$val"

      if [ -f services/team-portal/hotspot-setup.sh ] && command -v nmcli >/dev/null 2>&1; then
        sudo HOTSPOT_SSID="$HOTSPOT_SSID" HOTSPOT_PASSWORD="$HOTSPOT_PASSWORD" bash services/team-portal/hotspot-setup.sh || true
      fi
    fi
  fi

  echo -e "\n${C_CYAN}Levantando contenedores de Portal Web y PairDrop (LocalSend Web)...${C_RESET}"
  (cd services/team-portal && docker compose up -d)
  save_env
  echo -e "\n${C_GREEN}[OK] Servicio de comparticion de archivos y portal listos.${C_RESET}"
  pause
}

menu_select_services() {
  while true; do
    print_header
    echo -e "${C_BOLD}[SECCION 7] SELECCION Y DESPLIEGUE DE APLICACIONES EN CONTENEDOR${C_RESET}\n"
    
    local mark_obsidian=$([ "$ENABLE_OBSIDIAN" -eq 1 ] && echo -e "${C_GREEN}[X] ACTIVADO  ${C_RESET}" || echo -e "${C_RED}[ ] INACTIVO  ${C_RESET}")
    local mark_cicd=$([ "$ENABLE_CICD" -eq 1 ] && echo -e "${C_GREEN}[X] ACTIVADO  ${C_RESET}" || echo -e "${C_RED}[ ] INACTIVO  ${C_RESET}")
    local mark_network=$([ "$ENABLE_NETWORK" -eq 1 ] && echo -e "${C_GREEN}[X] ACTIVADO  ${C_RESET}" || echo -e "${C_RED}[ ] INACTIVO  ${C_RESET}")
    local mark_ai=$([ "$ENABLE_AI_SANDBOX" -eq 1 ] && echo -e "${C_GREEN}[X] ACTIVADO  ${C_RESET}" || echo -e "${C_RED}[ ] INACTIVO  ${C_RESET}")

    echo -e "  ${C_WHITE}1)${C_RESET} $mark_obsidian Obsidian LiveSync (CouchDB 3.3 - Puerto ${COUCHDB_PORT})"
    echo -e "  ${C_WHITE}2)${C_RESET} $mark_network DNS Seguro y Pi-hole (Adblock - Puerto ${PIHOLE_WEB_PORT})"
    echo -e "  ${C_WHITE}3)${C_RESET} $mark_cicd CI/CD (Gitea: ${GITEA_HTTP_PORT} + Jenkins: ${JENKINS_PORT})"
    echo -e "  ${C_WHITE}4)${C_RESET} $mark_ai Sandbox IA Local (Llama.cpp [${TARGET_ARCH}] - Puerto ${AI_PORT})"
    echo ""
    echo -e "  ${C_YELLOW}a)${C_RESET} Marcar todos       ${C_YELLOW}n)${C_RESET} Desmarcar todos"
    echo -e "  ${C_GREEN}d)${C_RESET} ${C_BOLD}Aplicar y Desplegar Seleccionados Ahora${C_RESET}"
    echo -e "  ${C_CYAN}c)${C_RESET} Volver al menu principal"
    echo ""
    echo -ne "${C_BOLD}Selecciona opcion (1-4, a, n, d, c): ${C_RESET}"
    read -r s_opt

    case "$s_opt" in
      1) ENABLE_OBSIDIAN=$((1 - ENABLE_OBSIDIAN)) ;;
      2) ENABLE_NETWORK=$((1 - ENABLE_NETWORK)) ;;
      3) ENABLE_CICD=$((1 - ENABLE_CICD)) ;;
      4) ENABLE_AI_SANDBOX=$((1 - ENABLE_AI_SANDBOX)) ;;
      a|A) ENABLE_OBSIDIAN=1; ENABLE_NETWORK=1; ENABLE_CICD=1; ENABLE_AI_SANDBOX=1 ;;
      n|N) ENABLE_OBSIDIAN=0; ENABLE_NETWORK=0; ENABLE_CICD=0; ENABLE_AI_SANDBOX=0 ;;
      d|D)
        save_env
        echo -e "\n${C_CYAN}Aplicando despliegue modular...${C_RESET}"
        [ "$ENABLE_OBSIDIAN" -eq 1 ] && (cd services/obsidian && docker compose up -d)
        [ "$ENABLE_NETWORK" -eq 1 ] && (cd services/network && docker compose up -d)
        [ "$ENABLE_CICD" -eq 1 ] && (cd services/cicd && docker compose up -d)
        [ "$ENABLE_AI_SANDBOX" -eq 1 ] && (cd services/ai-sandbox && docker compose up -d)
        echo -e "\n${C_GREEN}[OK] Stacks desplegados.${C_RESET}"
        pause
        ;;
      c|C|"")
        save_env
        break
        ;;
    esac
    save_env
  done
}

run_full_wizard() {
  print_header
  echo -e "${C_BOLD}[ASISTENTE GUIADO COMPLETO: INSTALACION DE CERO A PRODUCCION]${C_RESET}\n"
  echo -e " Este asistente configurara e instalara de forma secuencial todo tu sistema:"
  echo -e "  1. Seleccion de Arquitectura (ARM64 vs x86_64)"
  echo -e "  2. Dependencias del sistema operativo"
  echo -e "  3. Motor Docker Engine y Docker Compose"
  echo -e "  4. Red Privada y Certificados TLS con Tailscale"
  echo -e "  5. Seguridad de red, Firewall UFW y Fail2Ban"
  echo -e "  6. Gestor visual para navegador (Dockge / CasaOS)"
  echo -e "  7. Punto de Acceso Wi-Fi y LocalSend Web"
  echo -e "  8. Servicios (Obsidian LiveSync, Pi-hole, CI/CD, IA)"
  echo ""
  echo -ne "Deseas comenzar la instalacion completa ahora? (S/n): "
  read -r start_wiz
  if [[ "$start_wiz" =~ ^[nN]$ ]]; then
    return
  fi

  menu_architecture
  print_header
  install_system_deps
  install_docker_engine
  install_tailscale_vpn
  setup_security_firewall
  install_management_dashboard
  setup_hotspot_portal
  menu_select_services

  print_header
  echo -e "${C_GREEN}==========================================================================${C_RESET}"
  echo -e "${C_GREEN}${C_BOLD}   [OK] INSTALACION COMPLETA FINALIZADA CON EXITO                        ${C_RESET}"
  echo -e "${C_GREEN}==========================================================================${C_RESET}"
  echo -e "Tu servidor (${TARGET_ARCH}) esta listo y en funcionamiento."
  echo ""
  echo -e "${C_BOLD}ACCESOS ACTIVOS:${C_RESET}"
  [ "$MANAGEMENT_TOOL" = "dockge" ] || [ "$MANAGEMENT_TOOL" = "both" ] && echo -e " - Dockge:                   ${C_CYAN}http://localhost:${DOCKGE_PORT}${C_RESET}"
  [ "$ENABLE_HOTSPOT" -eq 1 ] && echo -e " - Portal Wi-Fi de Equipo:   ${C_CYAN}http://192.168.4.1:${PORTAL_PORT}${C_RESET} (Clave: $PORTAL_ACCESS_PASSWORD)"
  echo -e " - PairDrop / LocalSend Web: ${C_CYAN}http://localhost:${PAIRDROP_PORT}${C_RESET}"
  [ "$ENABLE_OBSIDIAN" -eq 1 ] && echo -e " - Obsidian CouchDB:          ${C_CYAN}http://localhost:${COUCHDB_PORT}${C_RESET}"
  [ "$ENABLE_NETWORK" -eq 1 ] && echo -e " - Pi-hole Admin:            ${C_CYAN}http://localhost:${PIHOLE_WEB_PORT}/admin${C_RESET}"
  
  local TS_DOM
  TS_DOM=$(tailscale status --json 2>/dev/null | grep -o '"Self":{[^}]*' | grep -o '"DNSName":"[^"]*' | cut -d'"' -f4 | sed 's/\.$//' || true)
  if [ -n "$TS_DOM" ]; then
    echo -e "\nDominio Tailscale (MagicDNS): ${C_YELLOW}${TS_DOM}${C_RESET}"
  fi
  echo -e "\nMonitoreo ServerBox en Android:"
  echo -e " Agrega tu servidor en ServerBox mediante SSH usando tu dominio o IP de Tailscale."
  pause
}

view_diagnostics() {
  print_header
  echo -e "${C_BOLD}[DIAGNOSTICO GENERAL DEL SISTEMA Y CONTENEDORES]${C_RESET}\n"
  
  echo -e "${C_CYAN}==> Estado del Demonio Docker:${C_RESET}"
  if command -v docker >/dev/null 2>&1; then
    docker info 2>/dev/null | grep -E "(Server Version|Operating System|Architecture|CPUs|Total Memory)" || true
    echo ""
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  else
    echo -e "${C_RED}[ERROR] Docker no esta instalado.${C_RESET}"
  fi

  echo -e "\n${C_CYAN}==> Estado de Red y Tailscale:${C_RESET}"
  tailscale status 2>/dev/null || echo -e "${C_YELLOW}[AVISO] Tailscale no esta activo.${C_RESET}"

  echo -e "\n${C_CYAN}==> Estado del Firewall UFW:${C_RESET}"
  sudo ufw status verbose 2>/dev/null || echo "UFW no activo."

  echo -e "\n${C_CYAN}==> Estado de Fail2Ban:${C_RESET}"
  sudo fail2ban-client status 2>/dev/null || echo "Fail2Ban no activo."
  pause
}

main_menu() {
  while true; do
    print_header
    echo -e " ${C_BOLD}PANEL PRINCIPAL DE INSTALACION Y CONFIGURACION:${C_RESET}\n"
    echo -e "  ${C_GREEN}${C_BOLD}[W] ASISTENTE GUIADO COMPLETO (Instalar todo de cero a produccion)${C_RESET}"
    echo -e "  ------------------------------------------------------------------------"
    echo -e "  ${C_CYAN}[1]${C_RESET} Arquitectura Objetivo ${C_YELLOW}[Actual: $TARGET_ARCH]${C_RESET}"
    echo -e "  ${C_CYAN}[2]${C_RESET} Instalar / Configurar Docker Engine y Compose"
    echo -e "  ${C_CYAN}[3]${C_RESET} Instalar / Configurar Tailscale (VPN Mesh + SSH)"
    echo -e "  ${C_CYAN}[4]${C_RESET} Configurar Seguridad (Firewall UFW + Fail2Ban)"
    echo -e "  ${C_CYAN}[5]${C_RESET} Instalar Gestor Web (Dockge / CasaOS para Laptops)"
    echo -e "  ${C_CYAN}[6]${C_RESET} Configurar Punto de Acceso Wi-Fi y Portal LocalSend"
    echo -e "  ${C_CYAN}[7]${C_RESET} Desplegar / Gestionar Apps (Obsidian, Pi-hole, CI/CD, IA)"
    echo -e "  ${C_CYAN}[8]${C_RESET} Diagnostico y Estado en Tiempo Real"
    echo -e "  ${C_CYAN}[9]${C_RESET} Detener Contenedores en Ejecucion"
    echo -e "  ${C_CYAN}[0]${C_RESET} Salir"
    echo ""
    echo -ne "${C_BOLD}Selecciona una opcion: ${C_RESET}"
    read -r option

    case "$option" in
      w|W) run_full_wizard ;;
      1) menu_architecture ;;
      2) install_docker_engine ;;
      3) install_tailscale_vpn ;;
      4) setup_security_firewall ;;
      5) install_management_dashboard ;;
      6) setup_hotspot_portal ;;
      7) menu_select_services ;;
      8) view_diagnostics ;;
      9)
        echo -e "\nDeteniendo stacks de contenedores..."
        for s in services/*/; do
          [ -f "$s/docker-compose.yml" ] && (cd "$s" && docker compose down 2>/dev/null || true)
        done
        echo -e "${C_GREEN}[OK] Contenedores detenidos.${C_RESET}"
        pause
        ;;
      0)
        echo -e "\n${C_GREEN}Sesion finalizada.${C_RESET}"
        exit 0
        ;;
      *)
        echo -e "${C_RED}Opcion no valida.${C_RESET}"
        sleep 1
        ;;
    esac
  done
}

if [ "$1" = "--wizard" ] || [ "$1" = "-w" ]; then
  run_full_wizard
elif [ "$1" = "--status" ]; then
  view_diagnostics
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Uso: ./deploy.sh [OPCION]"
  echo "  (sin argumentos)   Inicia la interfaz grafica de terminal interactiva (TUI)"
  echo "  -w, --wizard       Ejecuta el asistente de instalacion guiado completo"
  echo "  --status           Muestra el diagnostico de Docker, Tailscale y seguridad"
  exit 0
else
  main_menu
fi
