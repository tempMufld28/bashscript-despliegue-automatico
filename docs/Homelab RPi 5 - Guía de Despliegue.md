# **Servidor Homelab RPi 5 (ARM64) & ThinkCentre (x86_64) - Guía Maestra de Despliegue**

**Hardware Soportado:**
- **ARM64:** Raspberry Pi 5 (16GB RAM) + SSD NVMe PCIe (Case Argon NEO 5 NVMe) + Batería RTC + PD 45W + MicroSD 128GB.
- **x86_64:** Lenovo ThinkCentre / Mini PC / Intel NUC (multihilo AVX2/AVX512, memoria ampliable).
- **Sistema Operativo:** Raspberry Pi OS Lite (64-bit), Debian 12 o Ubuntu Server (instalaciones limpias sin modificar).

**Arquitectura de Red y Gestión:**
- **Acceso Privado & TLS:** Red Mesh privada Tailscale + MagicDNS + Certificados TLS automáticos
- **Exposición Pública Segura:** Tailscale Funnel (con whitelist/ACLs y túnel HTTPS inverso)
- **Gestión Visual Híbrida:** ServerBox (App móvil Android) + Dockge / CasaOS (Navegador web en Laptops)
- **Red Local de Colaboración:** Punto de Acceso Wi-Fi (Hotspot) autónomo + Portal Web con Webhook de dispositivos + PairDrop / LocalSend Web
- **Sincronización de Notas:** Obsidian Self-hosted LiveSync + CouchDB optimizado
- **Seguridad Activa:** Aislamiento de puertos en Localhost (`127.0.0.1`), Firewall UFW y protección contra fuerza bruta con Fail2Ban

---

## **1. Estrategia de Seguridad: Puertos, Escaneo, DDoS y Fail2Ban**

### **1.1 ¿Cambiar de puertos o usar Fail2Ban?**
* **La limitación de cambiar puertos (Seguridad por oscuridad):**
  Cambiar el puerto de un servicio únicamente detiene a los bots y rastreadores automatizados que barren internet buscando puertos estándar. Sin embargo, cualquier escaneo dirigido con herramientas como `nmap -p-` detecta el nuevo puerto en cuestión de segundos. Además, cambiar puertos obliga a memorizar URLs no estándar y complica la integración.

* **La solución profesional: Aislamiento por Tailscale + Fail2Ban:**
  1. **Enlace a Localhost (`127.0.0.1`):** En nuestros archivos `docker-compose.yml`, los servicios internos (CouchDB, Gitea, Jenkins, Dockge) no se mapean a `0.0.0.0`, sino a `127.0.0.1:<puerto>`. Esto significa que **ningún dispositivo en tu red local ni en internet puede escanearlos**. El puerto simplemente no existe para el mundo exterior.
  2. **Acceso vía Tailscale:** Solo los dispositivos autenticados en tu Tailnet pueden llegar a esos servicios mediante Tailscale SSH o `tailscale serve`.
  3. **Fail2Ban en el Host:** Se encarga de monitorear los intentos fallidos de autenticación (por ejemplo, en el servicio SSH o en los portales web) y añade reglas dinámicas en el firewall (`ufw` / `iptables`) para banear la IP del atacante automáticamente después de varios intentos.
  4. **Protección contra DDoS:** Al no tener puertos abiertos directamente en tu router de casa (sin port forwarding público) y usar Tailscale Funnel para compartir enlaces externos, cualquier ataque DDoS se estrella contra la infraestructura distribuida de Tailscale y Cloudflare, no contra la conexión de tu casa ni contra tu RPi 5.

---

## **2. Gestión de Contenedores: ServerBox (Móvil) + Dockge / CasaOS (Laptops)**

Para no depender de una TUI en terminal (como Lazydocker) y tener monitoreo y control en tiempo real:

### **2.1 ServerBox para Android**
ServerBox se conecta nativamente a la Raspberry Pi a través de SSH y la API de Docker:
- Muestra el estado del procesador Cortex-A76, temperatura, uso de los 16GB de RAM, tasa de transferencia del SSD NVMe y estado de cada contenedor Docker.
- **Configuración en Android:**
  1. Instala ServerBox desde Google Play o F-Droid.
  2. Agrega un nuevo servidor: Host = tu dominio de Tailscale (ej. `rpi5.tu-tailnet.ts.net`) o su IP de Tailscale (`100.x.y.z`).
  3. Autenticación: Usuario `pi` (o tu usuario) y tu llave SSH o contraseña.

### **2.2 Dockge / CasaOS para el Navegador Web en Laptop**
- **Dockge:** Panel web minimalista y reactivo accesible en el puerto `5001`. Permite ver todos los stacks de `docker-compose.yml`, editarlos en vivo con resaltado de sintaxis, ver logs en tiempo real y reiniciar servicios con un clic.
- **CasaOS:** Si prefieres una experiencia tipo escritorio con iconos grandes y tienda de apps para tu laptop, el instalador interactivo te permite instalarlo de manera nativa con un solo paso.
  CasaOS y ServerBox conviven perfectamente ya que ambos leen el mismo daemon de Docker de la máquina.

### **2.3 Arranque Automático en el Encendido (Auto-Boot)**
Todos los servicios se inicializan solos al prender la máquina gracias a:
1. El daemon de Docker habilitado con `sudo systemctl enable docker`.
2. La directiva `restart: unless-stopped` configurada en todos los contenedores de los archivos `docker-compose.yml`.

---

## **3. Punto de Acceso Wi-Fi (Hotspot) & Portal de Equipo (LocalSend / PairDrop)**

La máquina aprovecha su tarjeta Wi-Fi integrada (como en la RPi 5) para crear una red inalámbrica local autónoma, permitiendo que tu equipo de trabajo se conecte y comparta archivos a máxima velocidad sin depender del router del lugar ni de internet. Si se ejecuta en un servidor sin tarjeta Wi-Fi (ej. ThinkCentre por Ethernet), el instalador detecta la ausencia de tarjeta y despliega PairDrop para la red LAN cableada o Tailscale.

### **3.1 Arquitectura del Punto de Acceso**
- **Interfaz Wi-Fi:** Configurada mediante NetworkManager como Hotspot AP (IP fija `192.168.4.1/24` con servidor DHCP integrado).
- **Portal Web con Webhook (`puerto 8080`):**
  - Interfaz web oscura, estilizada y moderna.
  - Formulario de login/código de acceso para miembros del equipo.
  - Muestra en tiempo real:
    - Nombre de la red (SSID) y contraseña.
    - IP asignada a la RPi (Gateway).
    - **Tabla de dispositivos conectados** obtenida en tiempo real desde la tabla ARP/DHCP (`/proc/net/arp` / `ip neigh`).
    - **Webhook API (`/webhook/devices` y `/api/status`):** Entrega en formato JSON la lista de dispositivos conectados, sus IPs asignadas, direcciones MAC y estado.
- **PairDrop / LocalSend Web (`puerto 3000`):**
  - Servicio P2P de compartición de archivos ultrarrápido basado en WebRTC/WebSockets.
  - Los compañeros de equipo solo abren `http://192.168.4.1:3000` en Chrome, Safari o Firefox (desde iPhone, Android, Mac o Windows) y pueden enviarse archivos arrastrándolos, sin instalar apps.
  - Además, es 100% compatible con la app nativa de **LocalSend** (puerto `53317`).

---

## **4. Obsidian LiveSync + CouchDB**

Para sincronizar tus bóvedas de Obsidian en todos tus dispositivos (móvil, laptop, tablet) mediante el plugin oficial comunitario **Self-hosted LiveSync**:

1. **Servidor CouchDB 3.3:**
   - Desplegado en el puerto `5984` (enlazado de forma segura a `127.0.0.1` o accesible por Tailscale).
   - Configuración optimizada en `local.ini`:
     - `max_http_request_size = 4294967296` (soporta adjuntos grandes y sincronización inicial de notas).
     - CORS habilitado globalmente para solicitudes web y apps móviles.
2. **Conexión desde Obsidian:**
   - En Obsidian, instala el plugin comunitario **Self-hosted LiveSync**.
   - En la configuración del plugin:
     - **URI:** `https://tu-nodo.ts.net:5984` (o `http://100.x.y.z:5984`).
     - **Usuario / Contraseña:** Las credenciales definidas en tu `.env` (`COUCHDB_USER` y `COUCHDB_PASSWORD`).
     - **Database name:** `obsidian`.

---

## **5. Tailscale: TLS, MagicDNS y Funnels con Límites**

### **5.1 Certificados TLS y Dominio Seguro**
Tailscale gestiona automáticamente certificados HTTPS válidos de Let's Encrypt para tu nodo:
1. Activa **MagicDNS** y **HTTPS Certificates** en [login.tailscale.com](https://login.tailscale.com).
2. Tu nodo tendrá un dominio público válido, por ejemplo: `rpi5.tu-tailnet.ts.net`.

### **5.2 Tailscale Serve (Para ti y tus dispositivos autorizados)**
Permite acceder a los servicios locales mediante HTTPS cifrado sin abrir puertos:
```bash
# Servir Dockge por HTTPS en el puerto 443 de Tailscale:
sudo tailscale serve --bg https / http://127.0.0.1:5001

# Servir Obsidian CouchDB en un subdominio o puerto de Tailscale:
sudo tailscale serve --bg 5984 http://127.0.0.1:5984
```

### **5.3 Tailscale Funnel (Para invitados externos bajo White-List o límites)**
Si necesitas dar acceso temporal a alguien fuera de tu red Tailscale (por ejemplo a Gitea o al portal de archivos):
```bash
# Activar Funnel en el puerto 443 hacia el servicio deseado:
sudo tailscale funnel 443 on
sudo tailscale serve --bg https / http://127.0.0.1:3001
```

---

## **6. Instalador TUI Integral (`git clone` + `./deploy.sh`)**

El script [`deploy.sh`](file:///home/tempMufld28/Documentos/Pods/Despliegue%20de%20Nube/deploy.sh) es un instalador completo e interactivo que aprovisiona la máquina desde cero:

### **Paso a Paso:**

1. **Clona el repositorio en tu máquina (RPi 5 o ThinkCentre):**
   ```bash
   git clone <URL_DE_TU_REPOSITORIO> ~/homelab
   cd ~/homelab/"Despliegue de Nube"
   ```

2. **Ejecuta el instalador TUI:**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **Selecciona `[W]` para el Asistente Completo o navega modularmente:**
   - Detecta y adapta para **ARM64** o **x86_64**.
   - Instala paquetes del sistema (`curl`, `git`, `ufw`, `fail2ban`).
   - Instala **Docker Engine** y **Docker Compose** de los repositorios oficiales.
   - Instala, configura y vincula **Tailscale VPN** con **Tailscale SSH**.
   - Configura las reglas de firewall **UFW** y jaulas de **Fail2Ban**.
   - Instala **Dockge** o **CasaOS** según tu preferencia.
   - Configura el **Punto de Acceso Wi-Fi** y el portal de colaboración.
   - Despliega las aplicaciones seleccionadas (**Obsidian LiveSync**, **Pi-hole**, **CI/CD**, **Llama.cpp**).
