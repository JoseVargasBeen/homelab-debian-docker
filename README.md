# Lupin, mi servidor en casa

Tenía un PC de escritorio guardado sin usar. Le instalé Debian, lo conecté por
cable al router y desde diciembre de 2025 es mi servidor: nube propia,
gestor de contraseñas, una VPN para entrar a mi red desde el celular,
automatizaciones con n8n y la biblioteca de películas.

Todo va en contenedores de Docker y lo manejo desde Portainer. Hoy son
14 stacks y 22 contenedores en una máquina de 4 núcleos y 8 GB de RAM.

![Arquitectura del servidor](images/arquitectura.svg)

## Qué corre

| Servicio | Para qué lo uso |
|---|---|
| Portainer | Desplegar y administrar todo desde el navegador |
| Netdata | Ver CPU, RAM, disco y red en tiempo real |
| Heimdall | Página de inicio con accesos a cada servicio |
| Cloudflare Tunnel | Publicar los paneles con mi dominio y HTTPS sin abrir puertos web |
| WireGuard (wg-easy) | Conectarme a la red de casa desde el celular |
| Pi-hole | Bloquear publicidad por DNS, también cuando estoy en la VPN |
| Nextcloud | Mi reemplazo de Google Drive |
| Samba y File Browser | Carpeta compartida en la red y acceso desde el navegador |
| Vaultwarden | Servidor de contraseñas compatible con Bitwarden |
| WordPress | Sitio web autoalojado |
| n8n + PostgreSQL | Automatizaciones y webhooks |
| Emby, Transmission, Jackett | Películas y series |

## Cómo llego desde fuera

Para los paneles web uso un túnel de Cloudflare. El contenedor `cloudflared`
abre la conexión desde dentro de la casa, así que el router no tiene ningún
puerto web abierto y cada servicio queda en un subdominio con HTTPS.

Para todo lo demás uso WireGuard, que es el único puerto que reenvía el
router (51820/udp). Los clientes de la VPN usan Pi-hole como DNS, así que el
bloqueo de anuncios me sigue fuera de casa.

## Cómo se ve

![Portainer, vista general del entorno](images/portainer-dashboard.jpg)

![Lista de stacks en Portainer](images/portainer-stacks.jpg)

## Lo que hice mal (y ya corregí en parte)

Lo monté copiando plantillas de docker-compose y aprendiendo sobre la marcha.
Meses después revisé contenedor por contenedor y encontré cosas que no
volvería a hacer:

- **File Browser veía todo el disco.** Monté `/` completo dentro del
  contenedor. Ya está limitado a `/home`.
- **PostgreSQL estaba publicado en la red.** Lo había abierto "por si
  acaso". n8n se conecta por la red interna de Docker, así que no hacía falta.
  Cerrado.
- **Cualquiera podía registrarse en Vaultwarden.** Dejé el registro abierto
  después de crear mi cuenta. Cerrado.
- **n8n tenía acceso a `docker.sock`.** Lo monté con `:ro` creyendo que eso lo
  hacía seguro, pero no limita la API de Docker: un flujo comprometido podía
  controlar todo el servidor. Quitado.
- **Una contraseña escrita directamente en un compose.** Pendiente de cambiar.
- **Tailscale llevaba semanas caído.** La clave de autenticación venció y
  Docker lo reinició más de 60 000 veces sin que yo me diera cuenta. Me
  faltan alertas.

El detalle de los 22 puntos que encontré está en
[docs/AUDITORIA.md](docs/AUDITORIA.md). Los archivos de [`stacks/`](stacks/)
ya son la versión corregida: sin contraseñas (van en un `.env` que no se sube,
ver [`.env.example`](.env.example)), con versiones de imagen mantenidas y sin
las rutas de ejemplo que dejé sin cambiar en las plantillas.

## Si quieres montar algo parecido

Los pasos que seguí, desde la instalación de Debian hasta el túnel, están en
[docs/INSTALACION.md](docs/INSTALACION.md). En resumen:

```bash
git clone https://github.com/JoseVargasBeen/homelab-debian-docker.git
cd homelab-debian-docker
cp .env.example .env   # y llenarlo
cd stacks/portainer && docker compose up -d
```

Después, cada carpeta de `stacks/` se pega como un stack nuevo en Portainer.

En [`scripts/`](scripts/) dejé lo que uso para mantenerlo: una copia nocturna
de los volúmenes, una limpieza de imágenes y volúmenes sin uso, y la
configuración de Docker para que los logs no llenen el disco.

## Lo siguiente

- Poner Cloudflare Access delante de Portainer, n8n y Netdata.
- Copias de seguridad a un disco externo, no solo dentro del mismo PC.
- Que n8n me avise por Telegram cuando un contenedor se caiga.
