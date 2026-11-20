#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")/.."

project="petrobras-luizsiqueira"
context="kind-$project"
kubeconfig="$PWD/.local/kubeconfig"
kind="$PWD/.local/bin/kind"
kubectl="$PWD/.local/bin/kubectl"
helm="$PWD/.local/bin/helm"

for binary in "$kind" "$kubectl" "$helm"; do
  if [[ ! -x "$binary" ]]; then
    printf 'Binário ausente ou sem permissão de execução: %s\n' "$binary" >&2
    exit 1
  fi
done

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

docker info >/dev/null
export KIND_EXPERIMENTAL_PROVIDER=docker

clusters="$("$kind" get clusters)"
if grep -qxF "$project" <<< "$clusters"; then
  "$kind" export kubeconfig --name "$project" --kubeconfig "$kubeconfig"
else
  "$kind" create cluster --name "$project" \
    --config infra/kind/cluster.yaml \
    --kubeconfig "$kubeconfig" --wait 180s
fi

k=("$kubectl" --kubeconfig "$kubeconfig" --context "$context")
h=("$helm" --kubeconfig "$kubeconfig" --kube-context "$context")

"${k[@]}" wait --for=condition=Ready "node/$project-control-plane" --timeout=120s
"${k[@]}" create namespace "$project" --dry-run=client -o yaml |
  "${k[@]}" apply -f -

"${h[@]}" upgrade --install traefik traefik \
  --repo https://traefik.github.io/charts --version 39.0.0 \
  -n traefik --create-namespace -f infra/traefik/values.yaml \
  --wait --timeout 5m

"${h[@]}" upgrade --install metrics-server metrics-server \
  --repo https://kubernetes-sigs.github.io/metrics-server/ --version 3.13.0 \
  -n kube-system -f infra/metrics-server/values.yaml \
  --wait --timeout 5m

"${h[@]}" upgrade --install kyverno kyverno \
  --repo https://kyverno.github.io/kyverno/ --version 3.7.2 \
  -n kyverno --create-namespace --wait --timeout 5m

"${k[@]}" --warnings-as-errors apply \
  -f policies/petrobras-luizsiqueira-image-reference.yaml

"${k[@]}" get nodes
"${k[@]}" get deployments -A
