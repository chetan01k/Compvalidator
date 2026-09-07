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

        stage('Detect Release Tag') {
            steps {
                script {
                    // Get the Git tag for the checked-out commit, if any
                    def gitTag = sh(
                        script: "git describe --tags --exact-match 2>/dev/null || true",
                        returnStdout: true
                    ).trim()

                    env.GIT_TAG    = gitTag
                    env.IS_RELEASE = gitTag.startsWith("release-") ? "true" : "false"

                    echo "========================================"
                    echo "GIT TAG     : ${gitTag ?: '(none — plain branch push)'}"
                    echo "========================================"

                    if (env.IS_RELEASE == "false") {
                        echo "Not a release tag — skipping build/push stages. " +
                             "Normal branch pushes and non-release tags do not deploy."
                        currentBuild.displayName = "#${BUILD_NUMBER} - skipped (no release tag)"
                    }
                }
            }
        }

        stage('Validate POM Version') {
            when { environment name: 'IS_RELEASE', value: 'true' }
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

                    // The git tag must match release-<pomVersion> exactly —
                    // this works for ANY version, not just one hardcoded release
                    def expectedTag = "release-${pomVersion}"

                    echo "========================================"
                    echo "POM VERSION  : ${pomVersion}"
                    echo "GIT TAG      : ${env.GIT_TAG}"
                    echo "EXPECTED TAG : ${expectedTag}"
                    echo "========================================"

                    if (env.GIT_TAG != expectedTag) {
                        error(
                            "Tag/POM mismatch. Git tag '${env.GIT_TAG}' does not match " +
                            "the tag expected from pom.xml version '${pomVersion}' " +
                            "(expected '${expectedTag}')."
                        )
                    }

                    env.POM_VERSION = pomVersion
                    env.RELEASE_TAG = expectedTag

                    // Show the release version in the build display, not just the build number
                    currentBuild.displayName = "${env.RELEASE_TAG}"
                    currentBuild.description = "Git Tag: ${env.GIT_TAG} | POM Version: ${pomVersion}"

                    echo "VERSION VALIDATION SUCCESSFUL"
                }
            }
        }

        stage('Build & Package') {
            when { environment name: 'IS_RELEASE', value: 'true' }
            steps {
                sh '''
                    docker build \
                      -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} .
                '''
            }
        }

        stage('Docker Login') {
            when { environment name: 'IS_RELEASE', value: 'true' }
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
            when { environment name: 'IS_RELEASE', value: 'true' }
            steps {
                sh '''
                    docker push ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG}
                '''
            }
        }
    }

    post {

        success {
            script {
                if (env.IS_RELEASE == "true") {
                    echo "========================================"
                    echo "BUILD SUCCESSFUL"
                    echo "Git Tag : ${env.RELEASE_TAG}"
                    echo "Image   : ${REGISTRY}/${IMAGE_NAME}:${env.RELEASE_TAG}"
                    echo "========================================"
                } else {
                    echo "No release tag on this commit — nothing built or pushed."
                }
            }
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
