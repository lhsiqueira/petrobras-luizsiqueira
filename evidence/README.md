# Evidências da POC Kubernetes local

| Validação | Evidência |
|---|---|
| Pipeline completo para v0.1.1, build #4 | [Jenkins](jenkins-pipeline-success.png) |
| Pipeline completo para v0.1.2, build #5 | [Jenkins v0.1.2](jenkins-pipeline-v0.1.2.png) |
| Pipeline interrompido antes do build, push e deploy | [Jenkins bloqueado](jenkins-pipeline-blocked.png) |
| Quality Gate reprovado com 59,5% de cobertura em código novo frente ao mínimo de 80% | [SonarQube reprovado](sonarqube-pipeline-blocked.png) |
| Scan inicial com cinco achados HIGH | [Trivy v0.1.0](trivy-image-scan.txt) |
| Scan após atualização do Go, com zero achados HIGH ou CRITICAL | [Trivy v0.1.1](trivy-image-scan-v0.1.1.txt) |
| Autoscaling de uma para três réplicas durante carga pelo Ingress | [HPA](hpa-scale-up.md) |
| Métricas da aplicação no Grafana | [Prometheus e Grafana](grafana-metrics.png) |
| Logs JSON de requisições HTTP 200 no Grafana | [Promtail, Loki e Grafana](grafana-logs.png) |
| Kyverno aceitando digest e bloqueando imagens sem tag, com latest e init container com latest | [Admissão](kyverno-admission-final.txt) |
| Recuperação do rollout com DELETE permitido e latest ainda bloqueado | [Kyverno e rollout](kyverno-rollout-delete-validation.txt) |
| Rollback Helm e retorno da v0.1.2 pelo Ingress | [Rollback](helm-rollback.txt) |
