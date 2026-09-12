pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        skipDefaultCheckout(false)
    }

    environment {
        // Docker Hub
        REGISTRY        = "docker.io/chetan07k"
        IMAGE_NAME      = "compvalidator-app"

        // Release validation
        IS_RELEASE      = "false"
        RELEASE_TAG     = ""
        POM_VERSION     = ""
        EXPECTED_TAG    = ""
        DOCKER_IMAGE    = ""

        // Current requirement:
        // For release-1.2.6 the image must already exist.
        //
        // Change to "false" when creating a brand-new release tag.
        REQUIRE_EXISTING_IMAGE = "true"
    }

    stages {

        // ============================================================
        // 1. DETECT RELEASE TAG
        // ============================================================
        stage('Detect Release Tag') {
            steps {
                script {

                    def detectedTag = sh(
                        script: '''
                            set +e

                            TAG=$(git describe \
                                --exact-match \
                                --tags \
                                HEAD 2>/dev/null)

                            if [ -z "$TAG" ]; then
                                TAG="${TAG_NAME:-}"
                            fi

                            echo "$TAG"
                        ''',
                        returnStdout: true
                    ).trim()

                    if (detectedTag ==~ /^release-.+$/) {

                        env.IS_RELEASE = "true"
                        env.RELEASE_TAG = detectedTag

                        echo "========================================"
                        echo "RELEASE TAG DETECTED"
                        echo "RELEASE TAG : ${env.RELEASE_TAG}"
                        echo "========================================"

                    } else {

                        env.IS_RELEASE = "false"
                        env.RELEASE_TAG = ""

                        echo "========================================"
                        echo "NO RELEASE TAG"
                        echo "========================================"
                        echo "Current checkout is not a release-* tag."
                        echo "Release build/deployment will be skipped."
                        echo "========================================"
                    }
                }
            }
        }


        // ============================================================
        // 2. READ POM VERSION
        // ============================================================
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
                            set -e

                            docker run --rm \
                                --user "$(id -u):$(id -g)" \
                                -v "$PWD:/workspace" \
                                -w /workspace \
                                maven:3.9-eclipse-temurin-17 \
                                mvn -q \
                                -DforceStdout \
                                help:evaluate \
                                -Dexpression=project.version
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!pomVersion) {
                        error("Unable to read project version from pom.xml")
                    }

                    env.POM_VERSION = pomVersion

                    echo "========================================"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "========================================"
                }
            }
        }


        // ============================================================
        // 3. VALIDATE TAG AGAINST POM
        // ============================================================
        stage('Validate Release') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {

                    env.EXPECTED_TAG = "release-${env.POM_VERSION}"

                    echo "========================================"
                    echo "RELEASE VALIDATION"
                    echo "========================================"
                    echo "Git Tag        : ${env.RELEASE_TAG}"
                    echo "POM Version    : ${env.POM_VERSION}"
                    echo "Expected Tag   : ${env.EXPECTED_TAG}"
                    echo "========================================"

                    if (env.RELEASE_TAG != env.EXPECTED_TAG) {

                        error(
                            "Release validation failed. " +
                            "Git tag '${env.RELEASE_TAG}' does not match " +
                            "pom.xml version '${env.POM_VERSION}'. " +
                            "Expected '${env.EXPECTED_TAG}'."
                        )
                    }

                    env.DOCKER_IMAGE =
                        "${env.REGISTRY}/${env.IMAGE_NAME}:${env.RELEASE_TAG}"

                    echo "Docker Image : ${env.DOCKER_IMAGE}"
                }
            }
        }


        // ============================================================
        // 4. VERIFY DOCKER HUB IMAGE BEFORE BUILD
        // ============================================================
        stage('Verify Docker Hub Release') {
            when {
                expression {
                    env.IS_RELEASE == "true" &&
                    env.REQUIRE_EXISTING_IMAGE == "true"
                }
            }

            steps {
                script {

                    echo "========================================"
                    echo "VERIFY DOCKER HUB RELEASE"
                    echo "========================================"

                    echo "Checking:"
                    echo "${env.DOCKER_IMAGE}"

                    def result = sh(
                        script: '''
                            docker manifest inspect "${DOCKER_IMAGE}" \
                                >/dev/null 2>&1
                        ''',
                        returnStatus: true
                    )

                    if (result != 0) {

                        error(
                            "Docker Hub release image does not exist: " +
                            "${env.DOCKER_IMAGE}. " +
                            "Build stopped before compilation."
                        )
                    }

                    echo "========================================"
                    echo "DOCKER HUB IMAGE EXISTS"
                    echo "${env.DOCKER_IMAGE}"
                    echo "========================================"
                }
            }
        }


        // ============================================================
        // 5. BUILD + TEST + PACKAGE
        // ============================================================
        stage('Build & Test') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                sh '''
                    set -e

                    echo "========================================"
                    echo "MAVEN BUILD + TEST"
                    echo "========================================"

                    docker run --rm \
                        --user "$(id -u):$(id -g)" \
                        -v "$PWD:/workspace" \
                        -w /workspace \
                        maven:3.9-eclipse-temurin-17 \
                        mvn -B clean test package

                    echo "========================================"
                    echo "MAVEN BUILD SUCCESSFUL"
                    echo "========================================"
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


        // ============================================================
        // 6. DOCKER BUILD
        // ============================================================
        stage('Docker Build') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                sh '''
                    set -e

                    echo "========================================"
                    echo "DOCKER BUILD"
                    echo "========================================"

                    docker build \
                        --pull \
                        -t "${DOCKER_IMAGE}" \
                        .

                    echo "========================================"
                    echo "DOCKER BUILD SUCCESSFUL"
                    echo "IMAGE : ${DOCKER_IMAGE}"
                    echo "========================================"
                '''
            }
        }


        // ============================================================
        // 7. DOCKER LOGIN
        // ============================================================
        stage('Docker Login') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-registry-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {

                    sh '''
                        set -e

                        echo "========================================"
                        echo "DOCKER HUB LOGIN"
                        echo "========================================"

                        echo "$DOCKER_PASSWORD" | \
                            docker login docker.io \
                            --username "$DOCKER_USER" \
                            --password-stdin

                        echo "Docker Hub login successful."
                    '''
                }
            }
        }


        // ============================================================
        // 8. PUSH IMAGE
        // ============================================================
        stage('Docker Push') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                sh '''
                    set -e

                    echo "========================================"
                    echo "PUSHING IMAGE"
                    echo "========================================"

                    docker push "${DOCKER_IMAGE}"

                    echo "========================================"
                    echo "DOCKER PUSH SUCCESSFUL"
                    echo "${DOCKER_IMAGE}"
                    echo "========================================"
                '''
            }
        }


        // ============================================================
        // 9. VERIFY IMAGE AFTER PUSH
        // ============================================================
        stage('Verify Docker Hub After Push') {
            when {
                expression {
                    env.IS_RELEASE == "true"
                }
            }

            steps {
                script {

                    echo "========================================"
                    echo "VERIFY IMAGE AFTER PUSH"
                    echo "========================================"

                    sleep time: 5, unit: 'SECONDS'

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
                            "Image '${env.DOCKER_IMAGE}' was not found. " +
                            "Deployment stopped."
                        )
                    }

                    echo "========================================"
                    echo "DOCKER HUB IMAGE VERIFIED"
                    echo "${env.DOCKER_IMAGE}"
                    echo "========================================"
                }
            }
        }


        // ============================================================
        // 10. DEPLOY
        // ============================================================
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
                 * PUT YOUR REAL DEPLOYMENT COMMAND HERE.
                 *
                 * Example:
                 *
                 * sh '''
                 *     docker pull "${DOCKER_IMAGE}"
                 *     docker stop compvalidator || true
                 *     docker rm compvalidator || true
                 *     docker run -d \
                 *       --name compvalidator \
                 *       -p 8080:8080 \
                 *       "${DOCKER_IMAGE}"
                 * '''
                 */
            }
        }
    }


    // ================================================================
    // POST ACTIONS
    // ================================================================
    post {

        success {
            script {

                if (env.IS_RELEASE == "true") {

                    echo "========================================"
                    echo "RELEASE PIPELINE SUCCESSFUL"
                    echo "========================================"
                    echo "Release Tag : ${env.RELEASE_TAG}"
                    echo "POM Version : ${env.POM_VERSION}"
                    echo "Docker Image: ${env.DOCKER_IMAGE}"
                    echo "========================================"

                } else {

                    echo "========================================"
                    echo "PIPELINE SKIPPED"
                    echo "========================================"
                    echo "No release-* tag detected."
                    echo "No build performed."
                    echo "No Docker image pushed."
                    echo "No deployment performed."
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
            echo "Deployment was NOT completed."
            echo "========================================"
        }

        cleanup {
            sh '''
                docker logout docker.io >/dev/null 2>&1 || true
            '''
        }
    }
}
