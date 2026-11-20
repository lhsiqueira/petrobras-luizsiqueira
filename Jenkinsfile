pipeline {
    agent { label 'poc-wsl' }

    options {
        disableConcurrentBuilds()
        skipDefaultCheckout()
    }

    environment {
        POC_ROOT = '/home/luizsiqueira/petrobras-luizsiqueira'
        RELEASE = 'petrobras-luizsiqueira'
        APP_VERSION = 'v0.1.1'
        REGISTRY = '127.0.0.1:5001'
        TARGET_CONTEXT = 'kind-petrobras-luizsiqueira'
    }

    stages {
        stage('Checkout Git') {
            steps {
                deleteDir()
                sh '''
                    git clone --no-local -- "$POC_ROOT" .
                    git log -1 --oneline
                '''
            }
        }

        stage('Testes Go') {
            steps {
                sh '''
                    mkdir -p .local
                    go_image=$(awk '$1 == "FROM" && $4 == "build" {print $2; exit}' Dockerfile)
                    test -n "$go_image"

                    docker run --rm --user "$(id -u):$(id -g)" \
                      -e GOCACHE=/tmp/go-cache \
                      -v "$PWD/app:/src:ro" -v "$PWD/.local:/reports" \
                      -w /src "$go_image" \
                      go test -v -coverprofile=/reports/go-coverage.out ./...
                '''
            }
        }

        stage('SonarQube e Quality Gate') {
            steps {
                withCredentials([string(credentialsId: 'poc-sonar-token', variable: 'SONAR_TOKEN')]) {
                    sh '''
                        set +x
                        docker run --rm --user "$(id -u):$(id -g)" \
                          --network petrobras-luizsiqueira-sonar_default \
                          -e SONAR_HOST_URL=http://sonarqube:9000 \
                          -e SONAR_TOKEN -e SONAR_USER_HOME=/tmp/sonar \
                          -v "$PWD:/usr/src:ro" -w /usr/src \
                          sonarsource/sonar-scanner-cli:12.2.0.4256_8.1.0
                    '''
                }
            }
        }

        stage('Build da imagem') {
            steps {
                sh '''
                    image="$REGISTRY/$RELEASE/app:$APP_VERSION-build.$BUILD_NUMBER"
                    docker build --progress=plain \
                      --build-arg "APP_VERSION=$APP_VERSION" \
                      --tag "$image" .
                '''
            }
        }

        stage('Trivy') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    scan_dir="$(mktemp -d "$PWD/.local/scan.XXXXXX")"
                    trap 'rm -rf -- "$scan_dir"' EXIT
                    mkdir -p "$POC_ROOT/.local/trivy-cache"
                    image="$REGISTRY/$RELEASE/app:$APP_VERSION-build.$BUILD_NUMBER"
                    docker image save -o "$scan_dir/app.tar" "$image"

                    mkdir -p reports
                    docker run --rm --user "$(id -u):$(id -g)" \
                      -v "$scan_dir:/input:ro" \
                      -v "$POC_ROOT/.local/trivy-cache:/cache" \
                      ghcr.io/aquasecurity/trivy:0.69.3 \
                      --cache-dir /cache image --input /input/app.tar \
                      --scanners vuln --severity HIGH,CRITICAL \
                      --exit-code 10 --no-progress 2>&1 | tee reports/trivy.txt
                '''
            }
        }

        stage('Push no Nexus') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'poc-nexus-push',
                    usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASSWORD')]) {
                    sh '''#!/usr/bin/env bash
                        set -euo pipefail
                        set +x
                        docker_config="$(mktemp -d)"
                        trap 'rm -rf -- "$docker_config"' EXIT
                        image="$REGISTRY/$RELEASE/app:$APP_VERSION-build.$BUILD_NUMBER"

                        printf '%s' "$NEXUS_PASSWORD" |
                          docker --config "$docker_config" login "$REGISTRY" \
                            --username "$NEXUS_USER" --password-stdin
                        docker --config "$docker_config" push "$image" |
                          tee reports/nexus-push.txt

                        digest="$(awk '/digest: sha256:/ {
                            for (i=1; i<NF; i++) if ($i=="digest:") print $(i+1)
                        }' reports/nexus-push.txt | tail -1)"
                        [[ "$digest" =~ ^sha256:[a-f0-9]{64}$ ]]
                        printf '%s\\n' "$digest" > reports/image-digest.txt
                    '''
                }
            }
        }

        stage('Deploy Helm no kind') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    kubeconfig="$POC_ROOT/.local/kubeconfig"
                    kubectl="$POC_ROOT/.local/bin/kubectl"
                    helm="$POC_ROOT/.local/bin/helm"
                    chart="chart/$RELEASE"
                    digest="$(cat reports/image-digest.txt)"

                    "$kubectl" --kubeconfig "$kubeconfig" --context "$TARGET_CONTEXT" \
                      get node "$RELEASE-control-plane"

                    "$helm" --kubeconfig "$kubeconfig" --kube-context "$TARGET_CONTEXT" \
                      -n "$RELEASE" upgrade --install "$RELEASE" "$chart" \
                      -f "$chart/values-kind.yaml" \
                      --set-string "image.digest=$digest" \
                      --set-string "appVersion=$APP_VERSION" \
                      --wait --timeout 3m

                    "$kubectl" --kubeconfig "$kubeconfig" --context "$TARGET_CONTEXT" \
                      -n "$RELEASE" rollout status "deployment/$RELEASE" --timeout=90s
                '''
            }
        }

        stage('Smoke test pelo Ingress') {
            steps {
                sh '''#!/usr/bin/env bash
                    set -euo pipefail
                    host="$RELEASE.localhost"
                    curl --noproxy '*' --resolve "$host:8088:127.0.0.1" \
                      -fsS --retry 5 --retry-all-errors --max-time 5 \
                      -w 'HTTP %{http_code}\\n' "http://$host:8088/healthz" |
                      tee reports/healthz.txt
                    grep -qx 'ok' reports/healthz.txt

                    version_ok=false
                    for attempt in 1 2 3 4 5; do
                        echo "Verificando $APP_VERSION pelo Ingress ($attempt/5)"
                        if curl --noproxy '*' --resolve "$host:8088:127.0.0.1" \
                            --connect-timeout 2 --max-time 8 \
                            -fsS -o reports/app-version.json "http://$host:8088/" &&
                           python3 -c 'import json, sys; data = json.load(open(sys.argv[1])); print(data); sys.exit(data.get("version") != sys.argv[2])' \
                            reports/app-version.json "$APP_VERSION"; then
                            version_ok=true
                            break
                        fi
                        if [[ "$attempt" -lt 5 ]]; then
                            sleep 2
                        fi
                    done

                    if [[ "$version_ok" != true ]]; then
                        echo "O Ingress não confirmou a versão $APP_VERSION." >&2
                        exit 1
                    fi
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/*', allowEmptyArchive: true
        }
    }
}
