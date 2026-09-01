pipeline {
    agent any

    environment {
        REGISTRY   = "docker.io/chetan07k"
        IMAGE_NAME = "compvalidator-app"
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
                    def pomVersion = sh(
                        script: "grep -m1 '<version>' pom.xml | sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'",
                        returnStdout: true
                    ).trim()

                    env.RELEASE_TAG = "release-${pomVersion}"

                    echo "Resolved release tag: ${env.RELEASE_TAG}"
                }
            }
        }

        stage('Build & Package') {
            steps {
                sh '''
                    docker build \
                      -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} .
                '''
            }
        }

        stage('Docker Login') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASSWORD'
                )]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login docker.io \
                            --username "$DOCKER_USER" \
                            --password-stdin
                    '''
                }
            }
        }

        stage('Push to Registry') {
            steps {
                sh '''
                    docker push ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                '''
            }
        }
    }

    post {
        always {
            sh 'docker logout docker.io || true'
        }

        success {
            echo "Pushed ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
        }
    }
}
