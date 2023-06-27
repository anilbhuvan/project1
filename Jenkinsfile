pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('1116')
        AWS_SECRET_ACCESS_KEY = credentials('1116')
    }
    stages {
        stage('Checkout SCM') {
            steps {
                checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[url: 'https://github.com/anilbhuvan/project1']])
            }
        }

        stage('AWS Configuration') {
            steps {
                sh 'aws configure set region us-east-1'
                sh 'aws configure set output yaml'
            }  
        }


        stage('Creating s3 bucket and dynamodb table for terraform backend') {
            when {
                expression {
                    return params.options == '1st-apply'
                }
            }
            steps {
                sh '''
                    BUCKET_NAME="$(openssl rand -hex 12)"
                    echo $BUCKET_NAME > bucketname.txt
                    echo "Bucket name saved in $(pwd)/bucketname.txt"
                    sed -i "s/*BUCKET_NAME_PLACEHOLDER*/$BUCKET_NAME/g" infra/backend.tf
                    cat infra/backend.tf
                    aws s3api create-bucket --bucket $BUCKET_NAME --region us-east-1
                    aws s3api put-bucket-versioning --bucket $BUCKET_NAME --versioning-configuration Status=Enabled

                    aws dynamodb create-table \
                    --table-name lock-id-table \
                    --attribute-definitions \
                    AttributeName=LockID,AttributeType=S \
                    --key-schema AttributeName=LockID,KeyType=HASH \
                    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
                '''
            }  
        }

        stage('Sleep') {
            when {
                expression {
                    return params.options == '1st-apply'
                }
            }
            steps {
                sleep(time: 2, unit: 'MINUTES')
            }  
        }


        stage('initialize Terraform') {
            steps {
                dir('./infra/'){
                    sh 'terraform init'
                }
            }
        }

        stage(' terraform action') {
            when {
                expression {
                    return params.options == 'apply' || params.options == 'destroy'
                }
            }
            steps {
                dir('./infra/'){
                script {
                    def exitCode = sh(script: 'terraform plan -detailed-exitcode', returnStatus: true)
                    if (exitCode == 2) {
                            sh "terraform $options --auto-approve"
                        }
                    }
                }
            }
        }

        stage(' terraform apply for 1st time') {
            when {
                expression {
                    return params.options == '1st-apply'
                }
            }
            steps {
                dir('./infra/'){
                script {
                    def exitCode = sh(script: 'terraform plan -detailed-exitcode', returnStatus: true)
                    if (exitCode == 2) {
                        sh "terraform $options --auto-approve"
                        }
                    }
                }
            }
        }
    }
}
