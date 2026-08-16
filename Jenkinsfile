// KijaniKiosk CI Pipeline - kijanikiosk-payments
// Week 5 Friday capstone: single pipeline covering trigger -> build -> test
// -> security audit -> versioned artifact in Nexus.

pipeline {
    agent {
        docker {
            image 'node:18.20.4-alpine'
            args '-u root:root --network=minikube'
        }
    }

    options {
        timeout(time: 10, unit: 'MINUTES')
        disableConcurrentBuilds()
        timestamps()
    }

    environment {
        NEXUS_URL        = 'http://172.17.0.1:8081'
        NEXUS_REPOSITORY = 'kijanikiosk-npm-hosted'
        NEXUS_CREDENTIAL_ID = 'nexus-publisher'
        PACKAGE_NAME     = 'kijanikiosk-payments'
    }

    stages {

        stage('Lint') {
            steps {
                sh '''
                    npm ci --no-audit --no-fund
                    npm run lint
                '''
            }
        }

        stage('Build') {
            steps {
                sh 'npm run build'
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        sh 'npm test -- --ci --reporters=default --reporters=jest-junit'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'reports/junit/*.xml'
                        }
                    }
                }
                stage('Security Audit') {
                    steps {
                        sh 'npm audit --audit-level=high'
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                script {
                    env.GIT_SHA_SHORT = env.GIT_COMMIT.take(7)

                    def pkgVersion = sh(
                        script: "node -p \"require('./package.json').version\"",
                        returnStdout: true
                    ).trim()

                    env.ARTIFACT_VERSION = "${pkgVersion}-${env.GIT_SHA_SHORT}"
                }

                sh '''
                    mkdir -p dist-archive
                    tar -czf dist-archive/${PACKAGE_NAME}-${ARTIFACT_VERSION}.tgz dist/
                '''

                archiveArtifacts artifacts: 'dist-archive/*.tgz', fingerprint: true
            }
        }

        stage('Publish') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: env.NEXUS_CREDENTIAL_ID,
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                          npm version ${ARTIFACT_VERSION} --no-git-tag-version --allow-same-version

                          NPM_TOKEN=$(printf "%s:%s" "$NEXUS_USER" "$NEXUS_PASS" | base64 -w 0)
                          echo "//${NEXUS_URL#http://}/repository/${NEXUS_REPOSITORY}/:_auth=${NPM_TOKEN}" > .npmrc
                          echo "//${NEXUS_URL#http://}/repository/${NEXUS_REPOSITORY}/:always-auth=true" >> .npmrc

                          npm publish --registry ${NEXUS_URL}/repository/${NEXUS_REPOSITORY}/

                          rm -f .npmrc
                       '''
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                withEnv(['KUBECONFIG=/var/jenkins_home/.kube/config']) {
                    sh '''
                        which kubectl || (apk add --no-cache curl && \\
                          curl -LO https://dl.k8s.io/release/v1.31.0/bin/linux/amd64/kubectl && \\
                          chmod +x kubectl && mv kubectl /usr/local/bin/)
                        kubectl set image deployment/kk-payments \\
                          kk-payments=ghcr.io/wangareceline/kk-payments:${ARTIFACT_VERSION} \\
                          -n kijani-staging --record || \\
                        kubectl create deployment kk-payments \\
                          --image=ghcr.io/wangareceline/kk-payments:${ARTIFACT_VERSION} \\
                          -n kijani-staging
                        kubectl rollout status deployment/kk-payments -n kijani-staging --timeout=90s
                    '''
                }
            }
        }

        stage('Smoke Test') {
            steps {
                withEnv(['KUBECONFIG=/var/jenkins_home/.kube/config']) {
                    sh '''
                        kubectl port-forward -n kijani-staging deployment/kk-payments 3099:3001 &
                        PF_PID=$!
                        sleep 5
                        RESPONSE=$(curl -sf http://localhost:3099/health)
                        kill $PF_PID
                        echo "Smoke test response: $RESPONSE"
                        echo "$RESPONSE" | grep -q '"status":"ok"'
                    '''
                }
            }
        }

        stage('Approval Gate') {
            steps {
                timeout(time: 15, unit: 'MINUTES') {
                    input message: 'Smoke test passed. Approve deployment to production?',
                          submitter: 'admin',
                          parameters: [string(name: 'APPROVAL_REASON', description: 'Why is this approved?')]
                }
            }
        }

        stage('Deploy to Production') {
            steps {
                withEnv(['KUBECONFIG=/var/jenkins_home/.kube/config']) {
                    sh '''
                        kubectl set image deployment/kk-payments \\
                          kk-payments=ghcr.io/wangareceline/kk-payments:${ARTIFACT_VERSION} \\
                          -n default --record
                        kubectl rollout status deployment/kk-payments -n default --timeout=90s
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Artifact published: ${env.NEXUS_URL}/repository/${env.NEXUS_REPOSITORY}/${env.PACKAGE_NAME}/-/${env.PACKAGE_NAME}-${env.ARTIFACT_VERSION}.tgz"
        }
        failure {
            echo "Pipeline failed at build ${env.BUILD_NUMBER}. Notify: check console output for the failing stage."
        }
        changed {
            echo "Build status changed from previous run: now ${currentBuild.currentResult}"
        }
    }
} 

