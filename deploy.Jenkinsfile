pipeline{
    agent{
        docker{
            image 'docker:cli'
            args '-v /var/run/docker.sock:/var/run/docker.sock'
        }
    }

    triggers {
        githubPush()
    }

    options{
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time:25, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    environment{
        APP_NAME = 'nodeapp-Jenkins'
        IMAGE_TAG = "${env.GIT_COMMIT.take(7)}"

        // info about deployment server
        DEPLOY_SERVER = "185.199.53.175"
        DEPLOY_USER = "deploy"
        DEPLOY_PORT = "22"
        APP_PORT = "3000"

        // .env file pathway inside the production server
        ENV_FILE = "/home/deploy/devops-java/.env"
    }

    stages{
        stage("CD PIPELINE INFORMATION"){
            steps{
                script{
                    echo"""
                        CD PIPELINE INFO
                        ================

                        Build   : #${env.BUILD_NUMBER}
                        Branch  : ${env.BRANCH_NAME}
                        Commit SHA: ${IMAGE_TAG}
                        Deploy To: ${DEPLOY_SERVER}
                        Triggered By: ${env.BUILD_USER ?: 'GITHUB PUSH'}
                    """
                }
            }
        }

        stage("Build Docker Image"){
            steps{
                script{
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]){
                        sh"""
                            DOCKER_IMAGE="${DOCKER_USERNAME}/${APP_NAME}" 

                            echo "Building: \${DOCKER_IMAGE}:${IMAGE_TAG}"
                            docker build --platform linux/amd64 \\
                                --tag \${DOCKER_IMAGE}:${IMAGE_TAG} \\
                                --tag \${DOCKER_IMAGE}:latest \\
                                --file Dockerfile \\
                                .

                            echo "Successfully build"
                            docker images \${DOCKER_IMAGE}
                        """
                    }
                }
            }
        }

        stage("Security Scan"){
            steps{
                script{
                    withCredentials([
                        usernamePassword(
                            credentialsId : 'dockerhub-credentials',
                            usernameVariable : 'DOCKER_USERNAME',
                            passwordVariable : 'DOCKER_PASSWORD'
                        )
                    ]) {
                        sh"""
                            DOCKER_IMAGE="${DOCKER_USERNAME}/${APP_NAME}"

                            CONTAINER_UID=\$(docker run --rm --entrypoint id \${DOCKER_IMAGE}:${IMAGE_TAG} -u)

                            if [ "\${CONTAINER_UID}" = "0"]; then
                                echo "FAILED ... The user is root user."
                                exit 1
                            else
                                echo "Passed!.. The user is non-root user and their UID is (\${CONTAINER_UID})"
                            fi

                        """
                    }
                }
            }
        }

        
        stage("Push to DockerHub"){
            steps{
                script{
                    withCredentials([
                        usernamePassword(
                            credentialsId : 'dockerhub-credentials',
                            usernameVariable : 'DOCKER_USERNAME',
                            passwordVariable : 'DOCKER_PASSWORD'
                        )
                    ]) {
                        sh """
                            DOCKER_IMAGE ="${DOCKER_USERNAME}/${APP_NAME}"

                            echo "Logging to Dockerhub.."
                            echo \${DOCKER_PASSWORD} | docker login -u \${DOCKER_USERNAME} --password-stdin

                            echo "Pushing to Dockerhub..."
                            docker push \${DOCKER_IMAGE}:${IMAGE_TAG}
                            docker push \${DOCKER_IMAGE}:latest

                            docker logout
                            echo "PUSHED SUCCESSFULLY..!!!"

                        """
                    }
                }
            }
        }

        stage("Deploy to Production "){
            steps{
                script{
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]) {
                        sshagent(['deploy-jenkins-ssh-server']){
                            sh"""
                                DOCKER_IMAGE="${DOCKER_USERNAME}/${APP_NAME}"
                                
                                echo "Deploying to production"
                                echo "Server: ${DEPLOY_SERVER}"
                                echo "Image: \${DOCKER_IMAGE}:${IMAGE_TAG}"

                                ssh -o StrictHostKeyChecking=no \\
                                    -p ${DEPLOY_PORT}:${DEPLOY_PORT} \\
                                    ${DEPLOY_USER}@${DEPLOY_SERVER} >>SSHEND
                                
                                

                                #LOGIN to Dockerhub
                                echo \${DOCKER_PASSWORD} | docker login -u \${DOCKER_USERNAME} --password-stdin

                                # PULL new image
                                docker pull \${DOCKER_IMAGE}:${IMAGE_TAG}

                                # STOP and rm old container
                                docker stop ${APP_NAME} 2>/dev/null || true
                                docker rm ${APP_NAME} 2>/dev/null || true

                                # START new container with .env file
                                docker run -d \\
                                    --name ${APP_NAME} \\
                                    --restart unless-stopped \\
                                    --network teaching-network_default \\
                                    --env-file ${ENV_FILE} \\
                                    -p ${APP_PORT} \\
                                    \${DOCKER_IMAGE}:${IMAGE_TAG}

                                # VERIFY container if its running or not
                                sleep 5
                                docker ps | grep ${APP_NAME}

                                # LOGS monitor
                                docker logs --tail 20 ${APP_NAME}

                                # CLEANUP old images
                                docker images | grep \${DOCKER_IMAGE} | tail -n +6 | awk '{print \\\$3}' | xargs -r docker rmi || true

                                # LOGOUT
                                docker logout

                                echo 'Successfully Deployed!!'

                                SSHEND
                                
                            """
                        }
                    }
                }
            }
        }

        stage('Health Check') {
            steps {
                script {
                    sh """
                        echo "=== Preparing Health Check Environment ==="
                        
                        # [CHANGE: Use shell-compatible comments and install curl]
                        if ! command -v curl &> /dev/null; then
                            apk add --no-cache curl
                        fi

                        echo "=== Checking App on http://${DEPLOY_SERVER}:${APP_PORT}/ ==="
                        
                        # Giving the Spring Boot app time to initialize and connect to DB
                        sleep 30
                        
                        # [CHANGE: We use the root path since actuator is returning 404]
                        # -f ensures the pipeline fails if the response is 4xx or 5xx
                        curl -f http://${DEPLOY_SERVER}:${APP_PORT}/ || exit 1
                        # [END CHANGE]
                        
                        echo "Application is healthy!"
                        echo "Live at: http://${DEPLOY_SERVER}:${APP_PORT}"
                    """
                }
            }
        }

        stage('Cleanup Jenkins') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-credentials',
                            usernameVariable: 'DOCKER_USERNAME',
                            passwordVariable: 'DOCKER_PASSWORD'
                        )
                    ]) {
                        sh """
                            DOCKER_IMAGE="\${DOCKER_USERNAME}/${APP_NAME}"
                            docker rmi \${DOCKER_IMAGE}:${IMAGE_TAG} || true
                            docker rmi \${DOCKER_IMAGE}:latest || true
                            docker image prune -f || true
                            echo " Cleanup done"
                        """
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    echo """
                        DEPLOYMENT SUCCESSFUL - PRODUCTION LIVE  
                        =======================================


                        Image      : \${DOCKER_USERNAME}/${APP_NAME}:${IMAGE_TAG}
                        Commit SHA : ${IMAGE_TAG}
                        Server     : ${DEPLOY_SERVER}
                        Port       : ${APP_PORT}

                        Application: http://${DEPLOY_SERVER}:${APP_PORT}

                        
                    """
                }
            }
        }

        failure {
            echo """
                DEPLOYMENT FAILED  
                ===================


                Build    : #${env.BUILD_NUMBER}
                Commit   : ${IMAGE_TAG}
                Server   : ${DEPLOY_SERVER}
                Logs     : ${env.BUILD_URL}
                -----------------------------------

            """
        }

        always {
            sh 'docker image prune -f || true'
        }
    }
}
    