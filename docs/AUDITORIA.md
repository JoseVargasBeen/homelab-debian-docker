# Auditoría del servidor

Revisión hecha el **30/10/2026** a través de la API de Docker expuesta por Portainer:
contenedores, configuración de cada stack, imágenes, volúmenes, redes, logs y consumo de memoria.
El servidor llevaba **7 semanas encendido sin interrupciones** en el momento del análisis.

> Lo que no se pudo revisar desde Portainer: cortafuegos del host (ufw/nftables), SSH,
> actualizaciones de Debian, espacio en disco y copias de seguridad fuera de Docker.

Estado general: **20 de 22 contenedores funcionando**. Los servicios cumplían su función,
pero la configuración se hizo copiando plantillas y quedaron puertos, permisos y secretos
más abiertos de lo necesario.

> **Sobre esta versión pública.** Este servidor está conectado a internet, así que aquí solo
> aparecen los hallazgos ya corregidos y los que no afectan la seguridad. Los que siguen
> abiertos se documentan cuando estén resueltos.

---

## Corregidos

### File Browser con acceso a todo el disco
El contenedor montaba la **raíz completa del host** (`/:/data`) en modo lectura/escritura y
corría como root. Quien entrara en File Browser podía leer `/etc/shadow` o modificar cualquier
archivo del sistema.
**Corrección:** ahora solo ve `/home`.

### PostgreSQL publicado en todas las interfaces
`n8n-postgres` publicaba `0.0.0.0:5432` (el compose incluso decía "exponer para acceso externo").
**Corrección:** se quitó `ports:`; n8n se conecta por la red interna de Docker.

### Registro abierto en Vaultwarden
`SIGNUPS_ALLOWED=true` e `INVITATIONS_ALLOWED=true`: cualquiera que llegara a la URL podía
crearse una cuenta en el gestor de contraseñas.
**Corrección:** registro e invitaciones cerrados después de crear la cuenta propia.

### `docker.sock` dentro de n8n
n8n montaba `/var/run/docker.sock` "en solo lectura". **El `:ro` no protege nada**: solo impide
borrar el archivo, pero la API de Docker sigue permitiendo crear contenedores privilegiados.
Si un flujo o un webhook de n8n se veía comprometido, el atacante controlaba el servidor.
**Corrección:** se quitó el socket. Si algún día hace falta, irá detrás de un proxy como
`tecnativa/docker-socket-proxy` con permisos mínimos.

Los stacks afectados se volvieron a desplegar y arrancaron correctamente.

## Fallas de operación

### Tailscale caído en bucle de reinicio
Salió con el error `invalid key: API key does not exist`: la clave de autenticación caducó.
Docker intentó reiniciarlo **60 701 veces** sin que nadie se enterara. La lección no es la clave,
es que faltan alertas.
**Corrección:** clave reutilizable con etiqueta, o eliminar el stack si WireGuard ya cubre el
acceso remoto.

### phpMyAdmin no arranca
`bind: address already in use` en el puerto 8081: otro proceso del host ocupa ese puerto.
**Corrección:** cambiar el puerto y levantarlo solo cuando haga falta (`profiles: [admin]`).

### Dos conectores de Cloudflare
Hay dos contenedores `cloudflared`; uno se creó a mano fuera de cualquier stack, y los dos se
reconectan cada pocos minutos.
**Corrección:** dejar un solo conector gestionado por stack y forzar `--protocol http2`, que suele
estabilizar conexiones en redes domésticas donde QUIC/UDP se corta.

## Mantenimiento

| Hallazgo | Corrección |
|---|---|
| Rutas de ejemplo de las plantillas de LinuxServer sin cambiar (`/path/to/heimdall/config`…). La configuración quedaba en `/path/to/` en la raíz del disco, fuera de cualquier copia de seguridad. Emby montaba `/opt/vc/lib`, que solo existe en Raspberry Pi. | Rutas reales bajo `/opt/homelab/` |
| **MySQL 8.0** (WordPress) y **MariaDB 10.6** (Nextcloud) ya llegaron a fin de soporte. | Migrar a MySQL 8.4 LTS y MariaDB 11.4 LTS, con copia previa |
| Todas las imágenes usan `:latest` y no se actualizan desde diciembre de 2025. | Fijar versiones mayores; Watchtower en modo solo notificación o Renovate |
| Sin rotación de logs (`json-file` sin `max-size`): un contenedor ruidoso puede llenar el disco. | [`scripts/daemon.json`](../scripts/daemon.json) |
| Ningún contenedor tiene límite de memoria; Netdata solo consume ~755 MB. | `mem_limit` en los servicios pesados |
| `dperson/samba` está abandonada desde 2020. | Imagen mantenida (`dockurr/samba`) |

## Limpieza

- **Imágenes sin uso (~1,7 GB):** `nginx-proxy-manager`, `jc21/mariadb-aria`, `duckdns`,
  `hello-world`, `wg-easy:7` y una imagen huérfana.
- **Volúmenes sin uso:** unos 23.
- **Redes sin uso:** `ngixproxy_default` y `n8n_default`.
- **Zonas horarias mezcladas:** `Etc/UTC`, `America/Montevideo` y `America/Bogota` según el servicio.

Todo esto se limpia con [`scripts/limpieza-docker.sh`](../scripts/limpieza-docker.sh).
