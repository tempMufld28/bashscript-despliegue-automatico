#!/usr/bin/env python3
"""
Servidor Web Ligero para Portal de Red Local RPi y Webhook de Dispositivos Conectados.
"""
import os
import json
import subprocess
import socket
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, parse_qs

PORT = int(os.environ.get("PORTAL_PORT", "8080"))
PORTAL_PASSWORD = os.environ.get("PORTAL_ACCESS_PASSWORD", "TeamAccess2026")
HOTSPOT_SSID = os.environ.get("HOTSPOT_SSID", "RPi5-TeamNetwork")
PAIRDROP_URL = os.environ.get("PAIRDROP_URL", "http://192.168.4.1:3000")

def get_connected_devices():
    """Lee dispositivos conectados en la red local mediante /proc/net/arp o ip neigh."""
    devices = []
    try:
        if os.path.exists("/proc/net/arp"):
            with open("/proc/net/arp", "r") as f:
                lines = f.readlines()[1:]
                for line in lines:
                    parts = line.split()
                    if len(parts) >= 6:
                        ip, hw_type, flags, mac, mask, dev = parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]
                        if mac != "00:00:00:00:00:00" and flags != "0x0":
                            devices.append({
                                "ip": ip,
                                "mac": mac,
                                "interface": dev,
                                "status": "connected"
                            })
    except Exception as e:
        devices.append({"error": str(e)})

    # Intento de resolucion de nombres de host
    for d in devices:
        if "ip" in d:
            try:
                host = socket.gethostbyaddr(d["ip"])[0]
                d["hostname"] = host
            except Exception:
                d["hostname"] = "Desconocido"
    return devices

def get_system_ips():
    """Obtiene las IPs de las interfaces de red."""
    ips = {}
    try:
        output = subprocess.check_output(["ip", "-brief", "address", "show"], text=True)
        for line in output.strip().split("\n"):
            parts = line.split()
            if len(parts) >= 3:
                iface = parts[0]
                status = parts[1]
                addr = parts[2].split("/")[0] if parts[2] != "" else "N/A"
                ips[iface] = {"status": status, "ip": addr}
    except Exception:
        ips["local"] = {"status": "UP", "ip": "192.168.4.1"}
    return ips

class PortalHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        parsed = urlparse(self.path)
        
        if parsed.path == "/api/status" or parsed.path == "/webhook/devices":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            data = {
                "hotspot_ssid": HOTSPOT_SSID,
                "portal_password_configured": bool(PORTAL_PASSWORD),
                "pairdrop_url": PAIRDROP_URL,
                "interfaces": get_system_ips(),
                "connected_devices": get_connected_devices(),
                "devices_count": len(get_connected_devices())
            }
            self.wfile.write(json.dumps(data, indent=2).encode("utf-8"))
            return

        if parsed.path == "/" or parsed.path == "/index.html":
            self.path = "/static/index.html"

        return super().do_GET()

    def do_POST(self):
        parsed = urlparse(self.path)
        if parsed.path == "/api/login":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length).decode("utf-8")
            try:
                payload = json.loads(body)
                pwd = payload.get("password", "")
                if pwd == PORTAL_PASSWORD:
                    resp = {"success": True, "token": "team-access-authenticated-token"}
                else:
                    resp = {"success": False, "error": "Contrasena invalida"}
            except Exception:
                resp = {"success": False, "error": "Formato invalido"}

            self.send_response(200 if resp.get("success") else 401)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode("utf-8"))
            return

        self.send_response(404)
        self.end_headers()

if __name__ == "__main__":
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    server = HTTPServer(("0.0.0.0", PORT), PortalHandler)
    print(f"[INFO] Portal de Equipo iniciado en http://0.0.0.0:{PORT}")
    server.serve_forever()
