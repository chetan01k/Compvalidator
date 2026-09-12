pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY    = "docker.io/chetan07k"
        IMAGE_NAME  = "compvalidator-app"

        IS_RELEASE  = "false"
        RELEASE_TAG = ""
        POM_VERSION = ""
        DOCKER_IMAGE = ""
    }

    stages {

        stage('Detect Release Tag') {
            steps {
                script {
                    def detectedTag = sh(
                        script: '''
                            git tag --points-at HEAD 'release-*' | head -1
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!detectedTag) {
                        echo "========================================"
                        echo "NO RELEASE TAG"
                        echo "========================================"
                        echo "This is not a release build."
                        echo "Build and deployment will be skipped."
                        echo "========================================"

                        env.IS_RELEASE = "false"
                    } else {
                        env.IS_RELEASE = "true"
                        env.RELEASE_TAG = detectedTag

                        echo "========================================"
                        echo "RELEASE TAG DETECTED"
                        echo "RELEASE TAG : ${env.RELEASE_TAG}"
                        echo "========================================"
                    }
                }
            }
        }

        stage('Read POM Version') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {
                    def pomVersion = sh(
                        script: '''
                            grep -m1 '<version>' pom.xml |
                            sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!pomVersion) {
                        error("Unable to read version from pom.xml")
                    }

                    env.POM_VERSION = pomVersion

                    echo "========================================"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "RELEASE TAG : ${env.RELEASE_TAG}"
                    echo "========================================"
                }
            }
        }

        stage('Validate Release') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {
                    def expectedTag = "release-${env.POM_VERSION}"

                    echo "========================================"
                    echo "RELEASE VALIDATION"
                    echo "========================================"
                    echo "Git Tag      : ${env.RELEASE_TAG}"
                    echo "POM Version  : ${env.POM_VERSION}"
                    echo "Expected Tag : ${expectedTag}"
                    echo "========================================"

                    if (env.RELEASE_TAG != expectedTag) {
                        error(
                            "Tag/POM mismatch. " +
                            "Git tag '${env.RELEASE_TAG}' does not match " +
                            "pom.xml version '${env.POM_VERSION}'. " +
                            "Expected '${expectedTag}'."
                        )
                    }

                    env.DOCKER_IMAGE =
                        "${env.REGISTRY}/${env.IMAGE_NAME}:${env.RELEASE_TAG}"

                    echo "Release validation successful."
                    echo "Docker image: ${env.DOCKER_IMAGE}"
                }
            }
        }

        /*
         * IMPORTANT:
         *
         * Docker Hub MUST already contain the release image.
         *
         * If the image does not exist:
         *   - Pipeline FAILS
         *   - Maven Build does NOT run
         *   - Docker Build does NOT run
         *   - Docker Push does NOT run
         *   - Deploy does NOT run
         */
        stage('Verify Docker Hub Release') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {
                    echo "========================================"
                    echo "DOCKER HUB RELEASE CHECK"
                    echo "========================================"
                    echo "Checking:"
                    echo "${env.DOCKER_IMAGE}"
                    echo "========================================"

                    def result = sh(
                        script: '''
                            docker manifest inspect "${DOCKER_IMAGE}" \
                                >/dev/null 2>&1
                        ''',
                        returnStatus: true
                    )

                    if (result != 0) {
                        error(
                            "Docker Hub release image NOT FOUND: " +
                            "${env.DOCKER_IMAGE}. " +
                            "Build and deployment stopped."
                        )
                    }

                    echo "Docker Hub release image exists."
                    echo "Build and deployment may continue."
                }
            }
        }

        stage('Build') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                echo "========================================"
                echo "MAVEN BUILD"
                echo "========================================"

                sh '''
                    mvn -B clean package -DskipTests
                '''
            }
        }

        stage('Test') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

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

        stage('Docker Build') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                echo "========================================"
                echo "DOCKER BUILD"
                echo "========================================"
                echo "IMAGE: ${env.DOCKER_IMAGE}"
                echo "========================================"

                sh '''
                    docker build \
                        -t "${DOCKER_IMAGE}" \
                        .
                '''
            }
        }

        stage('Docker Login') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
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
            }
        }

        stage('Docker Push') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                echo "========================================"
                echo "DOCKER PUSH"
                echo "========================================"
                echo "IMAGE: ${env.DOCKER_IMAGE}"
                echo "========================================"

                sh '''
                    docker push "${DOCKER_IMAGE}"
                '''
            }
        }

        /*
         * Second verification.
         *
         * This confirms the image is still available after push.
         * Deploy cannot execute if verification fails.
         */
        stage('Verify Docker Hub After Push') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {
                    echo "========================================"
                    echo "VERIFY DOCKER HUB AFTER PUSH"
                    echo "========================================"

                    def result = sh(
                        script: '''
                            docker manifest inspect "${DOCKER_IMAGE}" \
                                >/dev/null 2>&1
                        ''',
                        returnStatus: true
                    )

                    if (result != 0) {
                        error(
                            "Docker Hub verification failed after push. " +
                            "Image '${env.DOCKER_IMAGE}' cannot be found. " +
                            "Deployment stopped."
                        )
                    }

                    echo "Docker Hub image verified successfully."
                }
            }
        }

        stage('Deploy') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                echo "========================================"
                echo "DEPLOY"
                echo "========================================"
                echo "Release : ${env.RELEASE_TAG}"
                echo "Version : ${env.POM_VERSION}"
                echo "Image   : ${env.DOCKER_IMAGE}"
                echo "========================================"

                /*
                 * ADD YOUR REAL DEPLOY COMMAND HERE.
                 *
                 * Example:
                 *
                 * sh '''
                 *     docker compose pull
                 *     docker compose up -d
                 * '''
                 */

                echo "Deploying ${env.DOCKER_IMAGE}"
            }
        }
    }

    post {
        success {
            script {
                if (env.IS_RELEASE == "true") {
                    echo "========================================"
                    echo "RELEASE PIPELINE SUCCESSFUL"
                    echo "========================================"
                    echo "Release : ${env.RELEASE_TAG}"
                    echo "Version : ${env.POM_VERSION}"
                    echo "Image   : ${env.DOCKER_IMAGE}"
                    echo "========================================"
                } else {
                    echo "========================================"
                    echo "PIPELINE SKIPPED"
                    echo "========================================"
                    echo "No release-* tag detected."
                    echo "No build or deployment performed."
                    echo "========================================"
                }
            }
        }

        failure {
            echo "========================================"
            echo "PIPELINE FAILED"
            echo "========================================"
            echo "Release : ${env.RELEASE_TAG}"
            echo "Version : ${env.POM_VERSION}"
            echo "Image   : ${env.DOCKER_IMAGE}"
            echo "========================================"
            echo "DEPLOYMENT NOT COMPLETED"
            echo "========================================"
        }

        cleanup {
            sh '''
                docker logout docker.io || true
            '''
        }
    }
}
