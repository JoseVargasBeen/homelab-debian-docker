#!/usr/bin/env bash
# Limpieza de recursos de Docker que ya no se usan.
# Muestra lo que se va a borrar y pide confirmación antes de hacerlo.
set -euo pipefail

echo "== Imágenes sin contenedor =="
docker images --filter dangling=false --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' | while IFS=$'\t' read -r img size; do
  if [ -z "$(docker ps -a --filter ancestor="$img" -q)" ]; then echo "  $img ($size)"; fi
done

echo "== Volúmenes huérfanos =="
docker volume ls --filter dangling=true --format '  {{.Name}}'

echo "== Redes sin uso =="
docker network ls --filter type=custom --format '{{.Name}}' | while read -r net; do
  if [ "$(docker network inspect -f '{{len .Containers}}' "$net")" = "0" ]; then echo "  $net"; fi
done

read -r -p "¿Borrar todo lo anterior? (escribe 'si'): " ok
[ "$ok" = "si" ] || { echo "Cancelado."; exit 0; }

docker image prune -a -f
docker volume prune -a -f
docker network prune -f
docker system df
