# Auditoría del servidor

Revisión hecha el **30/10/2026** a través de la API de Docker expuesta por Portainer:
contenedores, configuración de cada stack, imágenes, volúmenes, redes, logs y consumo de memoria.
El servidor llevaba **7 semanas encendido sin interrupciones** en el momento del análisis.

> Lo que no se pudo revisar desde Portainer: cortafuegos del host (ufw/nftables), SSH,
> actualizaciones de Debian, espacio en disco y copias de seguridad fuera de Docker.

## Resumen

| Severidad | Hallazgos |
|---|---|
| 🔴 Crítica | 5 |
| 🟠 Alta | 6 |
| 🟡 Media | 7 |
| 🔵 Baja / limpieza | 4 |

Estado general: **20 de 22 contenedores funcionando**. Los servicios cumplen su función,
pero la configuración se hizo copiando plantillas y quedaron puertos, permisos y secretos
más abiertos de lo necesario.

---

## 🔴 Críticas

### C1. Contraseña de Samba en texto plano
El stack `samba` crea el usuario pasando la contraseña dentro de `command:`. Cualquiera con
acceso a Portainer o a `docker inspect` la puede leer.
**Corrección:** cambiar la contraseña y pasarla por variable de entorno desde un `.env` que
no se versiona (ver [`stacks/samba`](../stacks/samba/compose.yaml)).

### C2. File Browser con acceso a todo el disco
El contenedor monta la **raíz completa del host** (`/:/data`) en modo lectura/escritura, corre
como root y usa una versión de 2022 (`hurlenko/filebrowser:v2.23.0`). Quien entre en File Browser
puede leer `/etc/shadow` o modificar cualquier archivo del sistema.
**Corrección:** montar solo una carpeta compartida, usar la imagen oficial actualizada y un
usuario sin privilegios.

### C3. PostgreSQL publicado en todas las interfaces
`n8n-postgres` publica `0.0.0.0:5432` (el compose incluso dice "exponer para acceso externo").
**Corrección:** quitar `ports:`; n8n se conecta por la red interna de Docker.

### C4. Registro abierto en Vaultwarden
`SIGNUPS_ALLOWED=true` e `INVITATIONS_ALLOWED=true`: cualquiera que llegue a la URL puede crearse
una cuenta en el gestor de contraseñas. Además, `ADMIN_TOKEN` está en texto plano.
**Corrección:** cerrar el registro tras crear la cuenta propia y usar un hash argon2 para el token.

### C5. `docker.sock` dentro de n8n
n8n monta `/var/run/docker.sock` "en solo lectura". **El `:ro` no protege nada**: solo impide
borrar el archivo, pero la API de Docker sigue permitiendo crear contenedores privilegiados.
Si un flujo o un webhook de n8n se ve comprometido, el atacante controla el servidor.
**Corrección:** quitar el socket, o usar un proxy como `tecnativa/docker-socket-proxy` con
permisos mínimos.

## 🟠 Altas

### A1. Portainer desactualizado y publicado en internet
Versión **2.33.6**, mientras Portainer avisa de la **2.45.3 LTS**, que corrige vulnerabilidades
críticas. Está publicado con Cloudflare Tunnel.
**Corrección:** actualizar y poner **Cloudflare Access** (correo + código) delante de los paneles
de administración.

### A2. Tailscale caído en bucle de reinicio
Salió con el error `invalid key: API key does not exist`: la clave de autenticación caducó.
Docker intentó reiniciarlo **60 701 veces** hasta que el runtime falló.
**Corrección:** generar una clave reutilizable con etiqueta, o eliminar el stack si WireGuard ya
cubre el acceso remoto.

### A3. phpMyAdmin no arranca
`bind: address already in use` en el puerto 8081: otro proceso del host ocupa ese puerto.
**Corrección:** cambiar el puerto y levantarlo solo cuando haga falta (`profiles: [admin]`).

### A4. Dos conectores de Cloudflare y reconexiones constantes
Hay dos contenedores `cloudflared`; uno (`cloudflared-warp`) se creó a mano fuera de cualquier
stack. En los logs de ambos aparece cada 2–5 minutos
`control stream encountered a failure while serving`, y ya acumulan 11 reinicios.
**Corrección:** dejar un solo conector gestionado por stack y forzar `--protocol http2`, que suele
estabilizar conexiones en redes domésticas donde QUIC/UDP se corta.

### A5. IP pública fija en WireGuard
`WG_HOST` tiene la IP pública escrita a mano. En una conexión doméstica esa IP cambia y los
clientes VPN dejan de conectar. Hay una imagen de DuckDNS descargada pero sin usar.
**Corrección:** usar un nombre DDNS.

### A6. Paneles publicados en `0.0.0.0`
Prácticamente todos los servicios publican su puerto en todas las interfaces. Docker añade
sus reglas **antes** que ufw, así que un cortafuegos en el host no los bloquea.
**Corrección:** publicar en `127.0.0.1` todo lo que se sirve por el túnel y dejar abiertos solo
los puertos de la LAN (SMB, DNS, Emby) y el de WireGuard.

## 🟡 Medias

| # | Hallazgo | Corrección |
|---|---|---|
| M1 | Rutas de ejemplo de las plantillas de LinuxServer sin cambiar (`/path/to/heimdall/config`, `/path/to/jackett/data`…). La configuración se guarda en `/path/to/` en la raíz del disco, fuera de cualquier copia de seguridad. Emby monta `/opt/vc/lib`, que solo existe en Raspberry Pi. | Rutas reales bajo `/opt/homelab/` |
| M2 | **MySQL 8.0** (WordPress) y **MariaDB 10.6** (Nextcloud) ya llegaron a fin de soporte. | Migrar a MySQL 8.4 LTS y MariaDB 11.4 LTS, con copia previa |
| M3 | Todas las imágenes usan `:latest` y no se actualizan desde diciembre de 2025. | Fijar versiones mayores; usar Watchtower en modo solo notificación o Renovate |
| M4 | Sin rotación de logs (`json-file` sin `max-size`): un contenedor ruidoso puede llenar el disco. | [`scripts/daemon.json`](../scripts/daemon.json) |
| M5 | Ningún contenedor tiene límite de memoria; Netdata solo consume ~755 MB. | `mem_limit` en los servicios pesados |
| M6 | `dperson/samba` está abandonada desde 2020. | Imagen mantenida (`dockurr/samba`) |
| M7 | Pi-hole v6 ignora `WEBPASSWORD`, así que la contraseña definida probablemente no se aplica. | `FTLCONF_webserver_api_password` |

## 🔵 Bajas / limpieza

- **Imágenes sin uso (~1,7 GB):** `nginx-proxy-manager`, `jc21/mariadb-aria`, `duckdns`,
  `hello-world`, `wg-easy:7` y una imagen huérfana.
- **Volúmenes sin uso:** unos 23, entre ellos `wireguardepihole_*` (el stack usa carpetas, no volúmenes).
- **Redes sin uso:** `ngixproxy_default` y `n8n_default`.
- **Zonas horarias mezcladas:** `Etc/UTC`, `America/Montevideo` y `America/Bogota` según el servicio.

Todo esto se limpia con [`scripts/limpieza-docker.sh`](../scripts/limpieza-docker.sh).

---

## Correcciones ya aplicadas (30/10/2026)

| Hallazgo | Cambio en el servidor | Estado |
|---|---|---|
| C2 | File Browser pasa de ver `/` a ver solo `/home` | ✅ Aplicado |
| C3 | Se quitó la publicación del puerto 5432 de PostgreSQL | ✅ Aplicado |
| C4 | Vaultwarden: `SIGNUPS_ALLOWED=false` e `INVITATIONS_ALLOWED=false` | ✅ Aplicado (falta el hash del `ADMIN_TOKEN`) |
| C5 | Se quitó `docker.sock` del contenedor de n8n | ✅ Aplicado |
| C1 | Cambiar la contraseña de Samba | ⏳ Pendiente (la cambia el dueño) |

Los tres stacks se volvieron a desplegar y arrancaron correctamente.

## Plan de corrección sugerido

1. Cambiar la contraseña de Samba y todas las que estaban en los compose (C1).
2. Restringir File Browser, cerrar el puerto 5432 y el registro de Vaultwarden (C2–C4).
3. Actualizar Portainer y poner Cloudflare Access delante de los paneles (A1, A6).
4. Quitar `docker.sock` de n8n (C5).
5. Dejar un solo `cloudflared`, arreglar o eliminar Tailscale y phpMyAdmin (A2–A4).
6. Configurar copias de seguridad con [`scripts/backup-volumenes.sh`](../scripts/backup-volumenes.sh).
7. Rotación de logs, límites de memoria, versiones fijas y limpieza (M y B).
