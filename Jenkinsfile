// KijaniKiosk CI Pipeline - kijanikiosk-payments
// Week 5 Friday capstone: single pipeline covering trigger -> build -> test
// -> security audit -> versioned artifact in Nexus.

pipeline {
    agent {
        docker {
            image 'node:18.20.4-alpine'
            args '-u root:root'
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
        NEXUS_CREDENTIAL_ID = 'nexus-publisher-nonexistent'
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

