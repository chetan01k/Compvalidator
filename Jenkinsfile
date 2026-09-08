pipeline {
    agent any

    tools {
        maven 'Maven-3.9'
    }

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY   = "docker.io/chetan07k"
        IMAGE_NAME = "compvalidator-app"
    }

    stages {

        stage('Build') {
            steps {
                checkout scm

                script {
                    def pomVersion = sh(
                        script: '''
                            grep -m1 '<version>' pom.xml |
                            sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'
                        ''',
                        returnStdout: true
                    ).trim()

                    env.POM_VERSION = pomVersion

                    currentBuild.displayName = pomVersion
                    currentBuild.description =
                        "Build and Deploy version ${pomVersion}"

                    echo "========================================"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "========================================"
                }

                echo "========================================"
                echo "MAVEN BUILD"
                echo "========================================"

                sh '''
                    mvn -B clean package -DskipTests
                '''
            }
        }

        stage('Test') {
            steps {
                echo "========================================"
                echo "RUNNING TESTS"
                echo "========================================"

                sh '''
                    mvn -B test
                '''
            }

            post {
                always {
                    junit(
                        testResults: '**/target/surefire-reports/*.xml',
                        allowEmptyResults: true
                    )
                }
            }
        }

        stage('Deploy') {
            when {
                expression {
                    return env.TAG_NAME?.startsWith('release-')
                }
            }

            steps {

                script {
                    def expectedTag = "release-${env.POM_VERSION}"

                    echo "========================================"
                    echo "RELEASE VALIDATION"
                    echo "========================================"
                    echo "TAG      : ${env.TAG_NAME}"
                    echo "POM      : ${env.POM_VERSION}"
                    echo "EXPECTED : ${expectedTag}"
                    echo "========================================"

                    if (env.TAG_NAME != expectedTag) {
                        error(
                            "Tag/POM mismatch. " +
                            "Tag '${env.TAG_NAME}' does not match " +
                            "POM version '${env.POM_VERSION}'. " +
                            "Expected '${expectedTag}'."
                        )
                    }

                    env.RELEASE_TAG = env.TAG_NAME
                }

                echo "========================================"
                echo "DOCKER BUILD"
                echo "========================================"

                sh '''
                    docker build \
                        -t ${REGISTRY}/${IMAGE_NAME}:${POM_VERSION} .
                '''

                echo "========================================"
                echo "DOCKER LOGIN"
                echo "========================================"

                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-registry-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login docker.io \
                            --username "$DOCKER_USER" \
                            --password-stdin
                    '''
                }

                echo "========================================"
                echo "DOCKER PUSH"
                echo "========================================"

                sh '''
                    docker push ${REGISTRY}/${IMAGE_NAME}:${POM_VERSION}
                '''

                echo "========================================"
                echo "DEPLOY"
                echo "========================================"

                echo "Deploying version ${POM_VERSION}"

                /*
                 * Add your actual deployment command here.
                 *
                 * Example:
                 *
                 * sh 'docker compose pull'
                 * sh 'docker compose up -d'
                 */
            }
        }
    }

    post {

        success {
            echo "========================================"
            echo "PIPELINE SUCCESSFUL"
            echo "VERSION : ${env.POM_VERSION}"
            echo "========================================"
        }

        failure {
            echo "========================================"
            echo "PIPELINE FAILED"
            echo "========================================"
        }

        cleanup {
            sh 'docker logout docker.io || true'
        }
    }
}
