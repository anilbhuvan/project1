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

        stage('1st-apply Creating s3 bucket and dynamodb table for terraform backend') {
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
                    sed -i "s/BUCKET_NAME_PLACEHOLDER/$BUCKET_NAME/g" infra/backend.tf
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

        stage('1st-apply Sleep') {
            when {
                expression {
                    return params.options == '1st-apply'
                }
            }
            steps {
                sleep(time: 2, unit: 'MINUTES')
            }  
        }

        stage('1st-apply initialize Terraform') {
            when {
                expression {
                    return params.options == '1st-apply'
                }
            }
            steps {
                dir('./infra/'){
                    sh 'terraform init -reconfigure'
                }
            }
        }

        stage('1st-apply terraform apply') {
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
                        sh "terraform apply --auto-approve"
                        }
                    }
                }
            }
        }







// might have a problem with BUCKET_NAME var when you create multiple s3
        stage('apply-destroy update backend file') {
            when {
                expression {
                    return params.options == 'apply' || params.options == 'destroy'
                }
            }
            steps {
                sh '''
                BUCKET_NAME=$(aws s3 ls | awk '{print $3}')
                sed -i "s/BUCKET_NAME_PLACEHOLDER/$BUCKET_NAME/g" infra/backend.tf
                cat infra/backend.tf 
                '''
            }
        }
        


        stage('apply-destroy initialize Terraform') {
            when {
                expression {
                    return params.options == 'apply' || params.options == 'destroy'
                }
            }
            steps {
                dir('./infra/'){
                    sh 'terraform init '
                }
            }
        }
        
        stage('apply-destroy terraform action') {
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
        

    }
}