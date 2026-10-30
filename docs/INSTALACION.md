# Cómo se montó el servidor

Guía paso a paso para reproducir el homelab en cualquier PC viejo.

## 1. Hardware

- PC de escritorio en desuso, x86_64, **4 núcleos y 8 GB de RAM**.
- Conectado **por cable Ethernet** al router de casa (más estable que el Wi-Fi para un servidor).
- Sin monitor ni teclado después de la instalación: todo se administra por SSH y Portainer.

## 2. Sistema operativo

1. Descargar la ISO *netinst* de **Debian** y grabarla en un USB (Rufus o Balena Etcher).
2. Instalar sin entorno de escritorio; marcar solo **servidor SSH** y **utilidades estándar del sistema**.
3. Nombre del equipo: `lupin`.
4. Reservar una **IP fija** para el servidor en el router (reserva DHCP por dirección MAC).

```bash
sudo apt update && sudo apt full-upgrade -y
sudo apt install -y curl git htop unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades   # parches de seguridad automáticos
```

## 3. Docker

```bash
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker $USER
sudo cp scripts/daemon.json /etc/docker/daemon.json   # rotación de logs
sudo systemctl restart docker
```

## 4. Portainer

```bash
cd stacks/portainer
docker compose up -d
```

Desde aquí, el resto de los servicios se despliegan como **Stacks** en Portainer:
*Stacks → Add stack → Web editor*. Se pega el `compose.yaml` correspondiente y los secretos
se cargan en *Environment variables* (ver [`.env.example`](../.env.example)).

## 5. Acceso desde fuera de casa

| Método | Para qué | Puertos en el router |
|---|---|---|
| **Cloudflare Tunnel** | Paneles web con HTTPS en un subdominio propio | Ninguno: el túnel sale desde el servidor |
| **WireGuard (wg-easy)** | Acceso completo a la red de casa y DNS de Pi-hole desde el móvil | `51820/udp` |
| **Tailscale** | Alternativa sin abrir puertos (opcional) | Ninguno |

### Cloudflare Tunnel
1. Pasar el dominio a Cloudflare.
2. *Zero Trust → Networks → Tunnels → Create tunnel* y copiar el token.
3. Desplegar [`stacks/cloudflared`](../stacks/cloudflared/compose.yaml) con ese token.
4. Añadir un *Public hostname* por servicio, por ejemplo `portainer.tudominio.com → http://localhost:9000`.
5. Recomendado: proteger los paneles de administración con **Cloudflare Access**.

## 6. Copias de seguridad

```bash
sudo cp scripts/backup-volumenes.sh /opt/homelab/scripts/
sudo crontab -e
# 0 3 * * * /opt/homelab/scripts/backup-volumenes.sh /mnt/backup >> /var/log/backup-homelab.log 2>&1
```

Lo ideal es que `/mnt/backup` sea un disco distinto o una carpeta sincronizada fuera de casa.
