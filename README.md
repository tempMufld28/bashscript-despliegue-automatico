# Despliegue de Nube - Instalador y Orquestador Homelab (TUI)

Suite interactiva basada en terminal para aprovisionar, configurar y desplegar servidores personales y homelabs desde la instalacion base del sistema operativo hasta produccion. Disenada para operar con arquitectura dual:

- **ARM64:** Optimizado para Raspberry Pi 5 (16GB RAM, SSD NVMe PCIe, perfiles termicos para CPU Cortex-A76).
- **x86_64:** Optimizado para Lenovo ThinkCentre, Intel NUC, Mini PCs y servidores dedicados (multihilo AVX2/AVX512).

---

## Modulos del Sistema

1. **Dependencias del Sistema Base:** Actualizacion de repositorios y paquetes esenciales (`curl`, `git`, `ufw`, `fail2ban`, `network-manager`, `htop`, `python3`).
2. **Motor de Contenedores:** Instalacion de Docker Engine CE y Docker Compose Plugin oficiales segun la arquitectura detectada, configuracion del daemon en systemd y asignacion de permisos de usuario.
3. **Red Privada y VPN Mesh (Tailscale):** Instalacion del cliente oficial, activacion de `tailscaled`, soporte de autenticacion no interactiva mediante Auth Key y habilitacion de Tailscale SSH.
4. **Seguridad y Firewall:** Politica de aislamiento mediante cortafuegos UFW (trafico cifrado permitido en `tailscale0` y puertos enlazados a `127.0.0.1`), junto con reglas activas de Fail2Ban para mitigar ataques de fuerza bruta en SSH y servicios web.
5. **Panel de Gestion Web:** Opcion de instalacion de Dockge (gestor de stacks Compose en contenedor) o CasaOS (interfaz web nativa), totalmente compatible con monitoreo movil mediante ServerBox (Android / iOS).
6. **Punto de Acceso Wi-Fi y Comparticion Local:** Deteccion de hardware inalambrico para emitir red local (`192.168.4.1/24`), portal de bienvenida con webhook de dispositivos conectados (`/api/status`) y servidor PairDrop (LocalSend Web) para transferencias P2P directas en navegador.
7. **Aplicaciones y Servicios en Contenedor:**
   - **Obsidian LiveSync:** Servidor CouchDB 3.3 configurado con CORS abierto y soporte para cargas de hasta 4GB.
   - **Pi-hole:** Servidor DNS con bloqueo de publicidad y telemetria.
   - **CI/CD:** Servidor Gitea con cliente SSH y servidor de automatizacion Jenkins.
   - **Sandbox IA:** Servidor de inferencia Llama.cpp con parametros de hilos y memoria adaptados dinamicamente a la arquitectura del procesador.

---

## Estructura del Repositorio

```text
Despliegue de Nube/
|-- deploy.sh                             # Instalador y orquestador interactivo TUI
|-- .env.example                          # Plantilla de variables de entorno y perfiles
|-- .gitignore                            # Exclusion de datos sensibles, logs y persistencia
|-- .gitattributes                        # Normalizacion de saltos de linea (LF)
|-- LICENSE                               # Licencia GNU General Public License v3.0 (GPL-3.0)
|-- README.md                             # Documentacion principal
|-- docs/
|   `-- Homelab RPi 5 - Guia de Despliegue.md # Documentacion tecnica de red y puertos
|-- services/
|   |-- management/docker-compose.yml     # Dockge
|   |-- team-portal/                      # Hotspot Wi-Fi, Webhook y PairDrop
|   |   |-- hotspot-setup.sh
|   |   |-- portal/ (server.py, static/index.html, Dockerfile)
|   |   `-- docker-compose.yml
|   |-- obsidian/                         # CouchDB 3.3 con configuracion local.ini
|   |   |-- local.ini
|   |   `-- docker-compose.yml
|   |-- cicd/docker-compose.yml           # Gitea y Jenkins
|   |-- network/docker-compose.yml        # Pi-hole
|   `-- ai-sandbox/docker-compose.yml     # Llama.cpp multiarquitectura
`-- security/
    |-- fail2ban/jail.local               # Filtros anti fuerza bruta
    `-- ufw-rules.sh                      # Reglas de cortafuegos
```

---

## Requisitos Previos

- Sistema Operativo: Raspberry Pi OS Lite (64-bit), Debian 12 (Bookworm) o Ubuntu Server (22.04 / 24.04 LTS).
- Usuario con privilegios de superusuario (`sudo`).
- Conexion a internet activa durante el primer aprovisionamiento.

---

## Guia de Instalacion Rapida

Clonar el repositorio en el directorio de usuario y ejecutar el instalador:

```bash
git clone <https://github.com/tempMufld28/bashscript-despliegue-automatico.git> ~/homelab
cd ~/homelab/
chmod +x deploy.sh
./deploy.sh
```

---

## Manual de la Interfaz de Terminal (TUI)

Al ejecutar `./deploy.sh` se inicia la navegacion interactiva:

```text
+------------------------------------------------------------------------+
|   INSTALADOR Y ORQUESTADOR DE NUBE HOMELAB                             |
|   Instalacion Modular de Cero a Produccion (Docker, Tailscale, Apps)   |
+------------------------------------------------------------------------+
 Arquitectura Objetivo: ARM64 | Docker: Instalado | Tailscale: Conectado
--------------------------------------------------------------------------

 PANEL PRINCIPAL DE INSTALACION Y CONFIGURACION:

  [W] ASISTENTE GUIADO COMPLETO (Instalar todo de cero a produccion)
  ------------------------------------------------------------------------
  [1] Arquitectura Objetivo [Actual: ARM64 / x86_64]
  [2] Instalar / Configurar Docker Engine y Compose
  [3] Instalar / Configurar Tailscale (VPN Mesh + SSH)
  [4] Configurar Seguridad (Firewall UFW + Fail2Ban)
  [5] Instalar Gestor Web (Dockge / CasaOS para Laptops)
  [6] Configurar Punto de Acceso Wi-Fi y Portal LocalSend
  [7] Desplegar / Gestionar Apps (Obsidian, Pi-hole, CI/CD, IA)
  [8] Diagnostico y Estado en Tiempo Real
  [9] Detener Contenedores en Ejecucion
  [0] Salir
```

### Opcion [W]: Asistente Guiado Completo
Ejecuta secuencialmente la deteccion de hardware, actualizacion del sistema, instalacion de Docker, configuracion de Tailscale, reglas de cortafuegos, despliegue del gestor web y orquestacion de contenedores seleccionados.

### Opciones Modulares [1 - 7]
Permite modificar parametros, reinstalar o actualizar unicamente componentes individuales segun la necesidad de infraestructura.

---

## Modos de Linea de Comandos (CLI Flags)

Para ejecuciones desatendidas o scripts de aprovisionamiento automatizado:

```bash
./deploy.sh --wizard   # Inicia directamente el asistente secuencial
./deploy.sh --status   # Muestra el diagnostico de contenedores, IPs y Tailscale
./deploy.sh --help     # Muestra las opciones de ayuda
```

---

## Licencia

Este proyecto esta distribuido bajo la licencia GNU General Public License v3.0 (GPL-3.0). Consulte el archivo [LICENSE](LICENSE) para mas detalles.
