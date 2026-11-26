pipeline {
    agent any

    environment {
        AWS_REGION     = 'us-east-2'
        AWS_ACCOUNT_ID = '942010118414'
        ECR_REPO       = 'hello-world-app'
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_URI      = "${ECR_REGISTRY}/${ECR_REPO}"

        CLUSTER_NAME   = 'tech-challenge-cluster'
        HELM_RELEASE   = 'hello-world'
        HELM_CHART     = 'helm/hello-world'   // path to the folder containing Chart.yaml
        K8S_NAMESPACE  = 'default'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    def shortSha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${shortSha}"
                }
                echo "Image tag for this build: ${env.IMAGE_TAG}"
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      -t $IMAGE_URI:$IMAGE_TAG \
                      -t $IMAGE_URI:latest \
                      app/
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION \
                      | docker login --username AWS --password-stdin $ECR_REGISTRY

                    docker push $IMAGE_URI:$IMAGE_TAG
                    docker push $IMAGE_URI:latest
                '''
            }
        }

        stage('Configure kubectl') {
            steps {
                sh '''
                    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
                    kubectl get nodes
                '''
            }
        }

        stage('Deploy with Helm') {
            steps {
                sh '''
                    helm upgrade --install $HELM_RELEASE $HELM_CHART \
                      --namespace $K8S_NAMESPACE --create-namespace \
                      --set image.repository=$IMAGE_URI \
                      --set image.tag=$IMAGE_TAG \
                      --wait --timeout 5m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    kubectl get pods,svc,hpa,ingress -n $K8S_NAMESPACE
                    helm list -n $K8S_NAMESPACE
                '''
            }
        }
    }

    post {
        success {
            echo "Deployed ${IMAGE_URI}:${IMAGE_TAG} to ${CLUSTER_NAME}"
        }
        failure {
            echo 'Pipeline failed — check the stage logs above.'
        }
        always {
            sh '''
                docker rmi $IMAGE_URI:$IMAGE_TAG $IMAGE_URI:latest || true
                docker image prune -f || true
            '''
        }
    }
}