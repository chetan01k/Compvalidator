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
                    /*
                     * Jenkins Multibranch Pipeline provides TAG_NAME
                     * when this build is running for a Git tag.
                     *
                     * Fallback to git describe in case TAG_NAME is not available.
                     */
                    def gitTag = env.TAG_NAME ?: sh(
                        script: "git describe --tags --exact-match 2>/dev/null || true",
                        returnStdout: true
                    ).trim()

                    env.GIT_TAG = gitTag

                    /*
                     * Only tags starting with "release-" are releases.
                     *
                     * Examples:
                     * release-1.2.5  -> RELEASE
                     * release-1.2.6  -> RELEASE
                     * 1.2.5          -> NOT RELEASE
                     * main           -> NOT RELEASE
                     */
                    env.IS_RELEASE = gitTag.startsWith("release-") ? "true" : "false"

                    echo "========================================"
                    echo "TAG_NAME    : ${env.TAG_NAME ?: '(none)'}"
                    echo "GIT TAG     : ${gitTag ?: '(none)'}"
                    echo "IS RELEASE  : ${env.IS_RELEASE}"
                    echo "========================================"

                    if (env.IS_RELEASE == "false") {
                        echo "Not a release tag - skipping build/push stages. " +
                             "Normal branch pushes and non-release tags do not deploy."

                        currentBuild.displayName =
                            "#${BUILD_NUMBER} - skipped (no release tag)"
                    }
                }
            }
        }

        stage('Validate POM Version') {
            when {
                environment name: 'IS_RELEASE', value: 'true'
            }

            steps {
                script {

                    /*
                     * Read version from pom.xml.
                     *
                     * Example:
                     * <version>1.2.5</version>
                     *
                     * Result:
                     * 1.2.5
                     */
                    def pomVersion = sh(
                        script: """
                            grep -m1 '<version>' pom.xml |
                            sed -E 's/.*<version>(.*)<\\/version>.*/\\1/'
                        """,
                        returnStdout: true
                    ).trim()

                    def expectedTag = "release-${pomVersion}"

                    echo "========================================"
                    echo "POM VERSION  : ${pomVersion}"
                    echo "GIT TAG      : ${env.GIT_TAG}"
                    echo "EXPECTED TAG : ${expectedTag}"
                    echo "========================================"

                    /*
                     * Make sure Git tag and pom.xml version match.
                     *
                     * Example:
                     *
                     * POM:
                     * 1.2.5
                     *
                     * Git tag:
                     * release-1.2.5
                     *
                     * Result:
                     * SUCCESS
                     */
                    if (env.GIT_TAG != expectedTag) {
                        error(
                            "Tag/POM mismatch. " +
                            "Git tag '${env.GIT_TAG}' does not match " +
                            "the tag expected from pom.xml version '${pomVersion}' " +
                            "(expected '${expectedTag}')."
                        )
                    }

                    env.POM_VERSION = pomVersion
                    env.RELEASE_TAG = expectedTag

                    /*
                     * Show release version in Jenkins.
                     */
                    currentBuild.displayName = "${env.RELEASE_TAG}"

                    currentBuild.description =
                        "Git Tag: ${env.GIT_TAG} | POM Version: ${pomVersion}"

                    echo "VERSION VALIDATION SUCCESSFUL"
                }
            }
        }

        stage('Build & Package') {
            when {
                environment name: 'IS_RELEASE', value: 'true'
            }

            steps {
                sh '''
                    docker build \
                      -t ${REGISTRY}/${IMAGE_NAME}:${RELEASE_TAG} .
                '''
            }
        }

        stage('Docker Login') {
            when {
                environment name: 'IS_RELEASE', value: 'true'
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
                        echo "$DOCKER_PASSWORD" | docker login docker.io \
                            --username "$DOCKER_USER" \
                            --password-stdin
                    '''
                }
            }
        }

        stage('Push to Registry') {
            when {
                environment name: 'IS_RELEASE', value: 'true'
            }

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
                    echo "Version : ${env.POM_VERSION}"
                    echo "Image   : ${REGISTRY}/${IMAGE_NAME}:${env.RELEASE_TAG}"
                    echo "========================================"

                } else {

                    echo "No release tag on this commit - nothing built or pushed."
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
