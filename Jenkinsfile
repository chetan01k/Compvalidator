pipeline {
    agent any

    environment {
        REGISTRY   = "docker.io/<your-dockerhub-user>"
        IMAGE_NAME = "compvalidator-app"
        REGISTRY_CREDS = credentials('docker-registry-creds')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Extract Version') {
            steps {
                script {
                    // Pulls <version> straight out of pom.xml without needing Maven on the host
                    def pomVersion = sh(
                        script: "grep -m1 '<version>' pom.xml | sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'",
                        returnStdout: true
                    ).trim()
                    env.RELEASE_TAG = "release-${pomVersion}"
                    echo "Resolved release tag: ${env.RELEASE_TAG}"
                }
            }
        }

        stage('Build & Package (Docker multi-stage)') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} ."
            }
        }

        stage('Push to Registry') {
            steps {
                sh """
                    echo "${REGISTRY_CREDS_PSW}" | docker login ${REGISTRY.split('/')[0]} -u "${REGISTRY_CREDS_USR}" --password-stdin
                    docker push ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                """
            }
        }
    }

    post {
        always {
            sh "docker logout ${REGISTRY.split('/')[0]} || true"
        }
        success {
            echo "Pushed ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
        }
    }
}
