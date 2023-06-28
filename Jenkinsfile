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

        stage('Process') {
            steps {
                script {
                    if (params.options == '1st-apply') {
                        // 1st-apply Creating s3 bucket and dynamodb table for terraform backend
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
                        // 1st-apply Sleep
                        sleep(time: 2, unit: 'MINUTES')
                        // 1st-apply initialize Terraform
                        dir('./infra/'){
                            sh 'terraform init -reconfigure'
                        }
                        // 1st-apply terraform apply
                        dir('./infra/'){
                            script {
                                def exitCode = sh(script: 'terraform plan -detailed-exitcode', returnStatus: true)
                                if (exitCode == 2) {
                                    sh "terraform apply --auto-approve"
                                }
                            }
                        }
                    } else if (params.options == 'apply' || params.options == 'destroy') {
                        // apply-destroy update backend file
                        sh '''
                            BUCKET_NAME=$(aws s3 ls | awk '{print $3}')
                            sed -i "s/BUCKET_NAME_PLACEHOLDER/$BUCKET_NAME/g" infra/backend.tf
                            cat infra/backend.tf 
                        '''
                        // apply-destroy initialize Terraform
                        dir('./infra/'){
                            sh 'terraform init '
                        }
                        // apply-destroy terraform action
                        dir('./infra/'){
                            script {
                                def exitCode = sh(script: 'terraform plan -detailed-exitcode', returnStatus: true)
                                if (exitCode == 2) {
                                    sh "terraform ${params.options} --auto-approve"
                                }
                            }
                        }
                    } else {
                        echo "Invalid option: ${params.options}"
                    }
                }
            }
        }
    }
}
