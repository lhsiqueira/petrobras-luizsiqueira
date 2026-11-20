# Relatório técnico

A POC executa em Kubernetes kind no WSL com Docker Desktop. O Jenkins usa um
agente WSL e obtém o código do Git local. O pipeline executa testes Go, aguarda
o Quality Gate do SonarQube, constrói a imagem, verifica vulnerabilidades com
Trivy, publica no Nexus e implanta por digest com Helm. A última etapa valida
o health check e a versão pelo Ingress Traefik.

O Metrics Server fornece a métrica de CPU usada pelo HPA. O Prometheus coleta
as métricas da aplicação por Pod. O Grafana consulta o Prometheus e o Loki, que
recebe os logs do Promtail. O Kyverno rejeita imagens sem versão explícita ou
com a tag latest no namespace da aplicação.

## Problemas encontrados e correções

- O Quality Gate reprovou 59,5% de cobertura em código novo diante do mínimo
  de 80%. Os testes de inicialização do servidor elevaram a cobertura local
  de statements de 64,0% para 84,6%, e o Quality Gate aprovou a nova análise.
- O Trivy encontrou cinco vulnerabilidades HIGH na biblioteca padrão do Go
  embutida na v0.1.0. A recompilação com Go 1.27.4 passou no scan a partir da
  v0.1.1, com zero achados HIGH ou CRITICAL na base utilizada.
- O webhook do Kyverno impediu o ReplicaSet de excluir um Pod antigo durante
  o rollout. A regra passou a corresponder explicitamente a CREATE e UPDATE.
  O teste posterior confirmou tanto a exclusão permitida quanto o bloqueio
  de imagens com latest.
- O upgrade do Grafana encontrou falha no init-chown-data e conflito entre
  Recreate e o campo rollingUpdate existente. A atualização preservou o PVC
  e foi concluída com Recreate e sem o chown recursivo no volume existente.
- O smoke test recebeu HTTP 200 em /healthz, mas uma chamada à raiz expirou.
  A verificação da versão passou a ter tentativas limitadas, mantendo a
  comparação do valor retornado com a versão esperada.
- O rollback restaurou a v0.1.1 e depois retornou à v0.1.2. Houve um HTTP 502
  transitório logo após a primeira troca. A nova tentativa confirmou a
  versão esperada e o Deployment terminou com uma réplica disponível.

## Melhorias futuras

Automatizar o bootstrap e o cadastro do job Jenkins, usar uma identidade
Kubernetes de deploy limitada ao namespace, migrar de Promtail para Grafana
Alloy e usar TLS no registry local. Avaliar a disponibilidade durante rollouts
e rollbacks com sondagem contínua pelo Ingress.
