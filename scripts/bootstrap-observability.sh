#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

project="petrobras-luizsiqueira"
context="kind-$project"
kubeconfig="$PWD/.local/kubeconfig"
namespace="observability"

if [[ ! -s "$kubeconfig" ]]; then
  printf 'Kubeconfig da POC ausente. Execute bootstrap-kind.sh primeiro.\n' >&2
  exit 1
fi

k=(.local/bin/kubectl --kubeconfig "$kubeconfig" --context "$context")
h=(.local/bin/helm --kubeconfig "$kubeconfig" --kube-context "$context"
   --namespace "$namespace")

"${k[@]}" get node "$project-control-plane"

"${h[@]}" upgrade --install prometheus prometheus \
  --repo https://prometheus-community.github.io/helm-charts \
  --version 29.47.2 --create-namespace \
  -f observability/prometheus-values.yaml --wait --timeout 5m

"${h[@]}" upgrade --install loki loki \
  --repo https://grafana.github.io/helm-charts --version 6.55.0 \
  -f observability/loki-values.yaml --wait --timeout 5m

"${h[@]}" upgrade --install promtail promtail \
  --repo https://grafana.github.io/helm-charts --version 6.17.0 \
  -f observability/promtail-values.yaml --wait --timeout 5m

"${h[@]}" upgrade --install grafana grafana \
  --repo https://grafana-community.github.io/helm-charts --version 10.5.15 \
  -f observability/grafana-values.yaml \
  -f observability/grafana-dashboards-values.yaml \
  -f observability/grafana-rollout-values.yaml \
  -f observability/grafana-loki-values.yaml \
  --set-file "dashboards.default.$project.json=observability/dashboards/$project.json" \
  --wait --timeout 5m

"${k[@]}" -n "$namespace" get pods,svc,pvc
