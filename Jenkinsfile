pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY   = "docker.io/chetan07k"
        IMAGE_NAME = "compvalidator-app"

        // Maven/JDK build container
        MAVEN_IMAGE = "maven:3.9-eclipse-temurin-21"

        // Docker CLI container
        DOCKER_IMAGE = "docker:27-cli"
    }

    stages {

        /*
         * ============================================================
         * DETECT RELEASE TAG
         * ============================================================
         *
         * Only release-* tags should continue through the pipeline.
         *
         * Examples:
         *
         * release-1.2.3  -> BUILD
         * release-2.0.0  -> BUILD
         *
         * main           -> SKIP
         * develop        -> SKIP
         * feature/test   -> SKIP
         * v1.2.3        -> SKIP
         */

        stage('Detect Release Tag') {
            steps {
                script {

                    echo "========================================"
                    echo "RELEASE DETECTION"
                    echo "========================================"

                    echo "TAG_NAME   : ${env.TAG_NAME}"
                    echo "BRANCH_NAME: ${env.BRANCH_NAME}"
                    echo "BUILD_TAG  : ${env.BUILD_TAG}"

                    if (env.TAG_NAME?.startsWith('release-')) {

                        env.IS_RELEASE = 'true'
                        env.RELEASE_TAG = env.TAG_NAME

                        echo "Release tag detected."
                        echo "RELEASE_TAG: ${env.RELEASE_TAG}"

                    } else {

                        env.IS_RELEASE = 'false'

                        echo "========================================"
                        echo "NOT A RELEASE BUILD"
                        echo "========================================"
                        echo "No release-* tag detected."
                        echo "Build/Test/Docker Push will be skipped."
                    }
                }
            }
        }


        /*
         * ============================================================
         * CHECKOUT
         * ============================================================
         */

        stage('Checkout') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "CHECKOUT SOURCE"
                echo "========================================"

                checkout scm

                sh '''
                    echo "Git commit:"
                    git rev-parse HEAD

                    echo ""
                    echo "Git tag:"
                    git describe --tags --exact-match HEAD || true
                '''
            }
        }


        /*
         * ============================================================
         * BUILD
         * ============================================================
         *
         * Maven and Java are provided by the container.
         *
         * Nothing needs to be installed on the Jenkins/provision server
         * for Java/Maven compilation.
         */

        stage('Build') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "MAVEN BUILD"
                echo "========================================"

                script {

                    docker.image(env.MAVEN_IMAGE).inside {

                        def pomVersion = sh(
                            script: '''
                                mvn -q \
                                  -Dexpression=project.version \
                                  -DforceStdout \
                                  help:evaluate
                            ''',
                            returnStdout: true
                        ).trim()

                        env.POM_VERSION = pomVersion

                        echo "========================================"
                        echo "VERSION INFORMATION"
                        echo "========================================"
                        echo "POM VERSION : ${env.POM_VERSION}"
                        echo "RELEASE TAG : ${env.RELEASE_TAG}"
                        echo "EXPECTED TAG: release-${env.POM_VERSION}"
                        echo "========================================"

                        def expectedTag = "release-${env.POM_VERSION}"

                        if (env.RELEASE_TAG != expectedTag) {

                            error(
                                "Tag/POM mismatch. " +
                                "Git tag '${env.RELEASE_TAG}' does not match " +
                                "POM version '${env.POM_VERSION}'. " +
                                "Expected '${expectedTag}'."
                            )
                        }

                        currentBuild.displayName = env.RELEASE_TAG

                        currentBuild.description =
                            "Build and Package ${env.RELEASE_TAG}"

                        echo "Tag/POM validation successful."

                        sh '''
                            mvn -B clean package -DskipTests
                        '''
                    }
                }
            }
        }


        /*
         * ============================================================
         * TEST
         * ============================================================
         *
         * Tests also run inside the Maven/JDK container.
         */

        stage('Test') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "RUNNING TESTS"
                echo "========================================"

                script {

                    docker.image(env.MAVEN_IMAGE).inside {

                        sh '''
                            mvn -B test
                        '''
                    }
                }
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
         *
         * IMPORTANT:
         *
         * The Docker image tag is the SAME as the Git release tag.
         *
         * Git:
         *     release-1.2.3
         *
         * Docker:
         *     chetan07k/compvalidator-app:release-1.2.3
         */

        stage('Docker Build') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "DOCKER BUILD"
                echo "========================================"

                script {

                    docker.image(env.DOCKER_IMAGE).inside(
                        '-v /var/run/docker.sock:/var/run/docker.sock'
                    ) {

                        sh '''
                            docker build \
                                -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} \
                                .
                        '''
                    }
                }

                echo "========================================"
                echo "IMAGE CREATED"
                echo "========================================"

                echo "${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
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
                    return env.IS_RELEASE == 'true'
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

                    script {

                        docker.image(env.DOCKER_IMAGE).inside(
                            '-v /var/run/docker.sock:/var/run/docker.sock'
                        ) {

                            sh '''
                                echo "$DOCKER_PASSWORD" | \
                                    docker login docker.io \
                                    --username "$DOCKER_USER" \
                                    --password-stdin
                            '''
                        }
                    }
                }
            }
        }


        /*
         * ============================================================
         * DOCKER PUSH
         * ============================================================
         *
         * SAME RELEASE TAG IS USED.
         *
         * Example:
         *
         * release-1.2.3
         *
         * becomes:
         *
         * docker.io/chetan07k/compvalidator-app:release-1.2.3
         */

        stage('Docker Push') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "DOCKER PUSH"
                echo "========================================"

                script {

                    docker.image(env.DOCKER_IMAGE).inside(
                        '-v /var/run/docker.sock:/var/run/docker.sock'
                    ) {

                        sh '''
                            docker push \
                                ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                        '''
                    }
                }

                echo "========================================"
                echo "IMAGE PUSHED"
                echo "========================================"

                echo "${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
            }
        }


        /*
         * ============================================================
         * DEPLOY
         * ============================================================
         *
         * Add the actual production deployment command here.
         *
         * Example:
         *
         * docker pull ...
         * docker compose up -d ...
         *
         * Kubernetes example:
         *
         * kubectl set image deployment/compvalidator ...
         */

        stage('Deploy') {

            when {
                expression {
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {

                echo "========================================"
                echo "DEPLOY"
                echo "========================================"

                echo "Deploying version:"
                echo "${RELEASE_TAG}"

                /*
                 * Add actual deployment command here.
                 */

                echo "Deployment command is currently not configured."
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

                if (env.IS_RELEASE == 'true') {

                    echo "========================================"
                    echo "RELEASE PIPELINE SUCCESSFUL"
                    echo "========================================"

                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "RELEASE TAG : ${env.RELEASE_TAG}"
                    echo "DOCKER IMAGE: ${env.REGISTRY}/${env.IMAGE_NAME}:${env.RELEASE_TAG}"

                    echo "========================================"

                } else {

                    echo "========================================"
                    echo "NON-RELEASE BUILD"
                    echo "========================================"

                    echo "No build/push/deployment performed."

                    echo "========================================"
                }
            }
        }

        failure {

            echo "========================================"
            echo "PIPELINE FAILED"
            echo "========================================"
        }

        cleanup {

            script {

                /*
                 * Logout only if this was a release build.
                 */

                if (env.IS_RELEASE == 'true') {

                    docker.image(env.DOCKER_IMAGE).inside(
                        '-v /var/run/docker.sock:/var/run/docker.sock'
                    ) {

                        sh '''
                            docker logout docker.io || true
                        '''
                    }
                }
            }
        }
    }
}
