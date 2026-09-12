pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY   = "docker.io/chetan07k"
        IMAGE_NAME = "compvalidator-app"

        IS_RELEASE = "false"
        RELEASE_TAG = ""
        POM_VERSION = ""
        DOCKER_IMAGE = ""
    }

    stages {

        /*
         * ============================================================
         * DETECT RELEASE TAG
         * ============================================================
         *
         * Only release-* tags are allowed to continue.
         *
         * Example:
         * release-1.2.7  -> RELEASE
         * main           -> SKIP
         * feature/test   -> SKIP
         * v1.2.7         -> SKIP
         */
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
                        echo "Current commit is not a release-* tag."
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


        /*
         * ============================================================
         * READ POM VERSION
         * ============================================================
         */
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
                        error("Could not determine version from pom.xml")
                    }

                    env.POM_VERSION = pomVersion

                    echo "========================================"
                    echo "VERSION INFORMATION"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "GIT TAG     : ${env.RELEASE_TAG}"
                    echo "========================================"
                }
            }
        }


        /*
         * ============================================================
         * VALIDATE RELEASE
         * ============================================================
         *
         * release-1.2.7 MUST match pom.xml version 1.2.7
         */
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
                    echo "GIT TAG     : ${env.RELEASE_TAG}"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "EXPECTED TAG: ${expectedTag}"
                    echo "========================================"

                    if (env.RELEASE_TAG != expectedTag) {

                        error(
                            "Release validation failed. " +
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
         * ============================================================
         * BUILD
         * ============================================================
         */
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


        /*
         * ============================================================
         * TEST
         * ============================================================
         */
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


        /*
         * ============================================================
         * DOCKER BUILD
         * ============================================================
         */
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


        /*
         * ============================================================
         * DOCKER LOGIN
         * ============================================================
         */
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


        /*
         * ============================================================
         * DOCKER PUSH
         * ============================================================
         */
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
                echo "Pushing: ${env.DOCKER_IMAGE}"
                echo "========================================"

                sh '''
                    docker push "${DOCKER_IMAGE}"
                '''
            }
        }


        /*
         * ============================================================
         * VERIFY DOCKER HUB RELEASE
         * ============================================================
         *
         * This is a HARD GATE.
         *
         * If Docker Hub does not contain the release image,
         * the pipeline FAILS.
         *
         * Deploy stage will NOT execute.
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
                    echo "VERIFY DOCKER HUB RELEASE"
                    echo "========================================"
                    echo "Checking: ${env.DOCKER_IMAGE}"
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
                            "Docker Hub verification FAILED. " +
                            "Image '${env.DOCKER_IMAGE}' was not found. " +
                            "Deployment stopped."
                        )
                    }

                    echo "========================================"
                    echo "DOCKER HUB RELEASE VERIFIED"
                    echo "========================================"
                    echo "Image exists:"
                    echo "${env.DOCKER_IMAGE}"
                    echo "Deployment is allowed."
                    echo "========================================"
                }
            }
        }


        /*
         * ============================================================
         * DEPLOY
         * ============================================================
         *
         * This stage is reached ONLY when:
         *
         * 1. release-* tag exists
         * 2. Git tag matches POM version
         * 3. Maven build succeeds
         * 4. Tests succeed
         * 5. Docker build succeeds
         * 6. Docker push succeeds
         * 7. Docker Hub image verification succeeds
         */
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
                echo "VERSION : ${env.POM_VERSION}"
                echo "RELEASE : ${env.RELEASE_TAG}"
                echo "IMAGE   : ${env.DOCKER_IMAGE}"
                echo "========================================"

                /*
                 * PUT YOUR ACTUAL DEPLOYMENT COMMAND HERE.
                 *
                 * Example:
                 *
                 * sh '''
                 *     docker compose pull
                 *     docker compose up -d
                 * '''
                 */

                echo "Deploying ${env.RELEASE_TAG}"
            }
        }
    }


    /*
     * ================================================================
     * POST ACTIONS
     * ================================================================
     */
    post {

        success {

            script {

                if (env.IS_RELEASE == "true") {

                    echo "========================================"
                    echo "PIPELINE SUCCESSFUL"
                    echo "========================================"
                    echo "RELEASE : ${env.RELEASE_TAG}"
                    echo "VERSION : ${env.POM_VERSION}"
                    echo "IMAGE   : ${env.DOCKER_IMAGE}"
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
            echo "DEPLOYMENT WAS NOT COMPLETED"
            echo "========================================"
        }

        cleanup {

            sh '''
                docker logout docker.io || true
            '''
        }
    }
}
