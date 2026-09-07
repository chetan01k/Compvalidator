pipeline {
    agent any

    options {
        timestamps()
    }

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

        stage('Extract & Validate Version') {
            steps {
                script {

                    // Read version from pom.xml
                    def pomVersion = sh(
                        script: """
                            grep -m1 '<version>' pom.xml |
                            sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'
                        """,
                        returnStdout: true
                    ).trim()

                    // Get the Git tag for the checked-out commit
                    def gitTag = sh(
                        script: """
                            git describe --tags --exact-match 2>/dev/null || true
                        """,
                        returnStdout: true
                    ).trim()

                    echo "========================================"
                    echo "POM VERSION : ${pomVersion}"
                    echo "GIT TAG     : ${gitTag}"
                    echo "========================================"

                    // Only version 1.2.5 is allowed
                    if (pomVersion != "1.2.5") {
                        error(
                            "Deployment is allowed only for version 1.2.5. " +
                            "Found POM version: ${pomVersion}"
                        )
                    }

                    // Pipeline must be triggered from a Git tag
                    if (!gitTag) {
                        error(
                            "No Git tag found. " +
                            "This pipeline can only run from a release tag."
                        )
                    }

                    // Only release-1.2.5 is allowed
                    def expectedTag = "release-1.2.5"

                    if (gitTag != expectedTag) {
                        error(
                            "Invalid Git tag. " +
                            "Expected: ${expectedTag}, " +
                            "Found: ${gitTag}"
                        )
                    }

                    // Docker image tag
                    env.RELEASE_TAG = "release-1.2.5"

                    // Show tag in Jenkins build
                    currentBuild.displayName =
                        "#${BUILD_NUMBER} - ${gitTag}"

                    currentBuild.description =
                        "Git Tag: ${gitTag} | POM Version: ${pomVersion}"

                    echo "========================================"
                    echo "VERSION VALIDATION SUCCESSFUL"
                    echo "Git Tag     : ${gitTag}"
                    echo "POM Version : ${pomVersion}"
                    echo "Docker Tag  : ${env.RELEASE_TAG}"
                    echo "========================================"
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

        success {
            echo "========================================"
            echo "BUILD SUCCESSFUL"
            echo "Git Tag : ${RELEASE_TAG}"
            echo "Image   : ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}"
            echo "========================================"
        }

        failure {
            echo "========================================"
            echo "BUILD FAILED"
            echo "========================================"
        }

        cleanup {
            script {
                if (env.WORKSPACE) {
                    sh 'docker logout docker.io || true'
                }
            }
        }
    }
}
