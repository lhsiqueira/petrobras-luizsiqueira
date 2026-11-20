# Escalonamento horizontal sob carga

- Data: 19/11/2026
- Cluster: kind-petrobras-luizsiqueira
- Namespace: petrobras-luizsiqueira
- Endpoint testado: http://petrobras-luizsiqueira.localhost:8088/
- Carga: 24 clientes concorrentes por 120 segundos
- HPA: alvo de CPU de 60%, mínimo de 1 réplica e máximo de 3

## Resultados observados

| Horário local | CPU / alvo | Réplicas prontas |
|---|---|---|
| 17:11:53 | 2% / 60% | 1 de 1 |
| 17:12:24 | 140% / 60% | 3 de 3 |
| 17:12:34 | 500% / 60% | 3 de 3 |

## Trechos da saída do terminal

    Carga concluída: 267804 HTTP 200, 0 falhas
    SuccessfulRescale: New size: 3; reason: cpu resource utilization (percentage of request) above target

O teste comprova a expansão automática de 1 para 3 réplicas sob carga pelo Ingress.
