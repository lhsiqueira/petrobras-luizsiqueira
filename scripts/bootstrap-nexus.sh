#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

project="petrobras-luizsiqueira"
node="$project-control-plane"
registry="$project-nexus:5001"

if [[ -n "${DOCKER_CONTEXT:-}" || -z "${DOCKER_HOST:-}" ]]; then
  docker_endpoint="$(docker context inspect "$(docker context show)" \
    --format '{{.Endpoints.docker.Host}}')"
else
  docker_endpoint="$DOCKER_HOST"
fi

if [[ "$docker_endpoint" != unix://* ]]; then
  printf 'Selecione o Docker local do WSL. Endpoint atual: %s\n' \
    "$docker_endpoint" >&2
  exit 1
fi

if ! cluster_label="$(docker inspect --format \
  '{{index .Config.Labels "io.x-k8s.kind.cluster"}}' "$node" 2>/dev/null)" ||
  [[ "$cluster_label" != "$project" ]]; then
  printf 'Nó kind da POC indisponível. Execute bootstrap-kind.sh primeiro.\n' >&2
  exit 1
fi

compose=(docker compose --project-name "$project" -f infra/nexus/compose.yaml)
"${compose[@]}" up -d

config_dir="/etc/containerd/certs.d/$registry"
docker exec "$node" mkdir -p "$config_dir"
docker exec -i "$node" tee "$config_dir/hosts.toml" >/dev/null <<TOML
server = "http://$registry"

[host."http://$registry"]
  capabilities = ["pull", "resolve"]
TOML

for attempt in {1..36}; do
  if curl --noproxy '*' -fsS --max-time 3 -o /dev/null \
    http://127.0.0.1:8081/service/rest/v1/status 2>/dev/null; then
    printf 'Nexus disponível em http://127.0.0.1:8081\n'
    "${compose[@]}" ps
    exit 0
  fi

  printf 'Aguardando Nexus (%s/36)\n' "$attempt"
  sleep 5
done

"${compose[@]}" ps -a
"${compose[@]}" logs --tail=60 nexus
exit 1
