pipeline {
  agent any

  triggers {
    pollSCM('H/2 * * * *')
  }

  options {
    disableConcurrentBuilds()
  }

  environment {
    AWS_DEFAULT_REGION = 'eu-west-2'
    AWS_PROFILE        = 'employee-lab'
    APP          = 'employee-api-sruthi'
    ACCOUNT      = sh(script: 'aws sts get-caller-identity --query Account --output text', returnStdout: true).trim()
    STATE_BUCKET = "employee-api-tfstate-${ACCOUNT}"
    REGISTRY     = "${ACCOUNT}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
    IMAGE        = "${REGISTRY}/${APP}"
    CLUSTER      = "${APP}-cluster"
    SERVICE      = "${APP}-service"
  }

  stages {
    stage('State bucket') {
      steps {
        sh '''
          if ! aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
            echo "Creating state bucket $STATE_BUCKET"
            aws s3api create-bucket --bucket "$STATE_BUCKET" --region "$AWS_DEFAULT_REGION" --create-bucket-configuration LocationConstraint="$AWS_DEFAULT_REGION"
            aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled
          else
            echo "State bucket already exists"
          fi
        '''
      }
    }

    stage('Create ECR') {
      steps {
        dir('terraform') {
          withCredentials([file(credentialsId: 'tfvars', variable: 'TFVARS')]) {
            sh 'terraform init -input=false -backend-config="bucket=$STATE_BUCKET"'
            sh 'terraform apply -input=false -auto-approve -var-file=$TFVARS -target=aws_ecr_repository.app'
          }
        }
      }
    }

    stage('Build') {
      steps {
        sh 'docker build --platform linux/amd64 -t $IMAGE:$BUILD_NUMBER -t $IMAGE:latest .'
      }
    }

    stage('Test') {
      steps {
        sh 'docker run --rm $IMAGE:latest python -c "import main"'
      }
    }

    stage('Push to ECR') {
      steps {
        sh 'aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY'
        sh 'docker push $IMAGE:$BUILD_NUMBER'
        sh 'docker push $IMAGE:latest'
      }
    }

    stage('Infrastructure') {
      steps {
        dir('terraform') {
          withCredentials([file(credentialsId: 'tfvars', variable: 'TFVARS')]) {
            sh 'terraform apply -input=false -auto-approve -var-file=$TFVARS'
          }
        }
      }
    }

    stage('Deploy to ECS') {
      steps {
        sh 'aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment'
        sh 'aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE'
      }
    }
  }
}