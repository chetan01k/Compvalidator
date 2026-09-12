pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        REGISTRY   = "docker.io/chetan07k"
        IMAGE_NAME = "compvalidator-app"
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

                    echo "========================================"
                    echo "RELEASE DETECTION"
                    echo "========================================"
                    echo "TAG_NAME       : ${env.TAG_NAME}"
                    echo "BRANCH_NAME    : ${env.BRANCH_NAME}"
                    echo "DETECTED TAG   : ${detectedTag}"
                    echo "========================================"

                    if (detectedTag) {
                        env.IS_RELEASE = 'true'
                        env.RELEASE_TAG = detectedTag

                        echo "Release tag detected: ${env.RELEASE_TAG}"
                    } else {
                        env.IS_RELEASE = 'false'

                        echo "No release tag on this commit."
                        echo "Build will be skipped."
                    }
                }
            }
        }

        stage('Build') {
            when {
                expression {
                    return env.IS_RELEASE == 'true'
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

                    env.POM_VERSION = pomVersion

                    def expectedTag = "release-${env.POM_VERSION}"

                    echo "========================================"
                    echo "RELEASE VALIDATION"
                    echo "========================================"
                    echo "POM VERSION : ${env.POM_VERSION}"
                    echo "RELEASE TAG : ${env.RELEASE_TAG}"
                    echo "EXPECTED    : ${expectedTag}"
                    echo "========================================"

                    if (env.RELEASE_TAG != expectedTag) {
                        error(
                            "Tag/POM mismatch. " +
                            "Tag '${env.RELEASE_TAG}' does not match " +
                            "POM version '${env.POM_VERSION}'. " +
                            "Expected '${expectedTag}'."
                        )
                    }

                    currentBuild.displayName = env.RELEASE_TAG
                    currentBuild.description =
                        "Build and package ${env.RELEASE_TAG}"

                    sh '''
                        mvn -B clean package -DskipTests
                    '''
                }
            }
        }

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
                    return env.IS_RELEASE == 'true'
                }
            }

            steps {
                echo "========================================"
                echo "DOCKER BUILD"
                echo "========================================"

                sh '''
                    docker build \
                        -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} \
                        .
                '''

                sh '''
                    docker image inspect \
                        ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                '''
            }
        }

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
                    sh '''
                        echo "$DOCKER_PASSWORD" | \
                        docker login docker.io \
                        --username "$DOCKER_USER" \
                        --password-stdin
                    '''
                }
            }
        }

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

                sh '''
                    docker push \
                        ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                '''

                echo "========================================"
                echo "PUSH COMPLETE"
                echo "========================================"

                echo "${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
            }
        }

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

                echo "Deploying ${RELEASE_TAG}"

                // Add production deployment here.
            }
        }
    }

    post {
        success {
            echo "========================================"
            echo "PIPELINE SUCCESSFUL"
            echo "========================================"

            script {
                if (env.IS_RELEASE == 'true') {
                    echo "VERSION : ${env.POM_VERSION}"
                    echo "TAG     : ${env.RELEASE_TAG}"
                    echo "IMAGE   : ${env.REGISTRY}/${env.IMAGE_NAME}:${env.RELEASE_TAG}"
                } else {
                    echo "No release tag detected."
                    echo "Nothing was built or pushed."
                }
            }
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
