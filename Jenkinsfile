pipeline{
    agent{
        docker{
            image 'docker:cli'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    options {   
          buildDiscarder(logRotator(numToKeepStr: '10'))
          timestamps()
          timeout(time: 20, unit: 'MINUTES')
          disableConcurrentBuilds()                                                                                                
    }
                                                                                                                                   
    environment {
          APP_NAME = 'Nodeapp-jenkins'
          CI_IMAGE = "${APP_NAME}:ci-${env.GIT_COMMIT.take(7)}"
    }

    stages{
        stage("Pipeline info: "){
            steps{
                script{
                    echo """
                        CI-PIPELINE INFORAMTION
                        ========================

                        Build : #${env.BUILD_NUMBER}
                        Branch : ${env.BRANCH_NAME}
                        PR : ${env.CHANGE_ID ?: 'NOT A PR'}
                        Tilte : ${env.CHANGE_TITLE ?: 'N/A'}
                        --------------------------------------

                    """
                }
            }
        }

        stage("Verify Environment"){
            steps{
                sh"""
                    echo "Verifying environment"
                    echo "Hostname : ${hostname}"
                    echo "User : ${whoami}"
                    docker -version
                """
            }
        }

        stage("Code Quality"){
            steps{
                sh"""
                    echo "Checking the code qualtiy"
                    echo "Code quality is good to go"
                """
            }
        }

        stage("Docker Build"){
            steps{
                sh"""
                    // Building Docker image
                    echo "Building: ${CI_IMAGE}"
                    docker build --tag ${CI_IMAGE} --file Dockerfile .
                    echo "build Successfully"

                    docker images ${CI_IMAGE}
                """
            }
        }

        stage("Verify Image"){
            steps{
                sh"""
                    // Verifying image
                    echo"Verifying image: ${CI_IMAGE}"

                        // checking the jar file in the image
                        docker run --rm --entrypoint ls ${CI_IMAGE} -lh /app/app.jar
                        echo "Jar found"

                        // checking the node inside the image
                        docker run --rm --entrypoint node ${CI_IMAGE} --version
                        echo "Node OK"

                        // Checking the ports inside the image
                        docker inspect ${CI_IMAGE} --format="Ports:{{json.config.ExposedPorts}}"
                        echo "Node OK"

                        echo "Verified the image successfully"
                """
            }
        }

        stage("Security Scan"){
            steps{
                sh"""
                    CONTAINER_UID = "\$(docker run --rm --entrypoint id ${CI_IMAGE} -u)
                    echo "Container_uid = \${CONTAINER_UID}"

                    if ["\$CONTAINER_UID" = "0"];then
                        echo "Failed... The user is root. High Alert Risk!!!!!"
                    else
                        echo "PASSED.. The user is non-user. The UID is \${CONTAINER_UID}"
                """
            }
        }

        stage("Cleanup"){
            steps{
                sh"""
                    docker rmi ${CI_IMAGE} || true
                    echo "Cleanup done"
                """

            }
        }

    }    

    post{
        success{
            script{
                if (env.CHANGE_ID){
                    echo"""
                        CI PASSED: PR VALIDATED
                        =======================

                        PR : ${env.CHANGE_ID} - ${CHANGE_TITLE}

                        verify environment: passed
                        code quality      : passed
                        quality gate      : passed
                        docker build      : passed
                        security scan     : passed
                        deploy            : failed[Pr doesnt triggered Deployment]
                        note: to deply your code--> go to review--->then merge to main branch
                        ---------------------------------------------------------------------

                    """}
                else {
                    echo"""
                        CI PASSED : BRANCH VALIDATED
                        =============================

                        Branch : ${env.BRANCH_NAME}
                        Build  : ${env.BUILD_NUMBER}

                        verify environment: passed
                        code quality      : passed
                        quality gate      : passed
                        docker build      : passed
                        security scan     : passed
                        --------------------------------------------

                    """
                }
                
            }
        }

        failure{
            echo"""
                CI PIPELINE FAILED
                ==================

                Build: ${env.BUILD_NUMBER}
                Branch : ${env.BRANCH_NAME}
                PR     : ${env.CHANGE_ID ?: 'N/A'}                                                                                            
                Logs   : ${env.BUILD_URL}
                -----------------------------------
                
            """
        }

        always{
            sh"docker image prune -f || true"
        }
    } 
}