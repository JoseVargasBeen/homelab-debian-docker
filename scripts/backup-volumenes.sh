#!/usr/bin/env bash
# Copia de seguridad de los volúmenes de Docker con datos importantes.
# Uso:  sudo ./backup-volumenes.sh /ruta/destino
# Programar con cron, por ejemplo cada noche a las 3:00:
#   0 3 * * * /opt/homelab/scripts/backup-volumenes.sh /mnt/backup >> /var/log/backup-homelab.log 2>&1
set -euo pipefail

DESTINO="${1:-/mnt/backup}"
FECHA="$(date +%F)"
DIAS_A_CONSERVAR=14

VOLUMENES=(
  vaultwarden_vaultwarden-data
  nextcloud_nextcloud
  nextcloud_db
  wordpress_wordpress_data
  wordpress_db_data
  n8n_n8n-data
  n8n_postgres-data
)

mkdir -p "$DESTINO/$FECHA"

for vol in "${VOLUMENES[@]}"; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "[$(date +%T)] Copiando $vol"
    docker run --rm \
      -v "$vol":/origen:ro \
      -v "$DESTINO/$FECHA":/destino \
      alpine tar czf "/destino/$vol.tar.gz" -C /origen .
  else
    echo "[$(date +%T)] Aviso: el volumen $vol no existe, se omite"
  fi
done

# Volcado lógico de las bases de datos (más fiable que copiar los archivos en caliente)
docker exec n8n-postgres pg_dump -U n8n n8n | gzip > "$DESTINO/$FECHA/n8n.sql.gz" || true

find "$DESTINO" -mindepth 1 -maxdepth 1 -type d -mtime +"$DIAS_A_CONSERVAR" -exec rm -rf {} +
echo "[$(date +%T)] Copia terminada en $DESTINO/$FECHA"
