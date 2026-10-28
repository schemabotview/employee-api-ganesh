// Jenkins owns the application: build, test, push, roll out.
// Terraform (the infrastructure) is owned by GitHub Actions - see
// .github/workflows/terraform.yml - so the two never fight over state.
pipeline {
  agent any

  triggers {
    pollSCM('H/2 * * * *')
  }

  options {
    disableConcurrentBuilds()
    timestamps()
    buildDiscarder(logRotator(numToKeepStr: '20'))
  }

  environment {
    AWS_DEFAULT_REGION = 'eu-west-2'
    APP                = 'employee-api-ganesh'
    CLUSTER            = "${APP}-cluster"
    SERVICE            = "${APP}-service"
  }

  stages {
    stage('Build') {
      steps {
        sh 'docker build --platform linux/amd64 -t $APP:$BUILD_NUMBER -t $APP:latest .'
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eu

          # app imports cleanly
          docker run --rm $APP:latest python -c "import main; print('import ok')"

          # and actually serves /health. Jenkins is a sibling container here, so
          # probe from inside the app container instead of over localhost.
          cid=$(docker run -d $APP:latest)
          trap 'docker rm -f "$cid" >/dev/null 2>&1 || true' EXIT

          probe="import sys, urllib.request
try:
    print(urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2).read().decode())
except Exception:
    sys.exit(1)"

          for i in $(seq 1 20); do
            if docker exec "$cid" python -c "$probe"; then
              echo "health ok"
              exit 0
            fi
            sleep 1
          done

          echo "health check never passed"
          docker logs "$cid"
          exit 1
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-jenkins',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY',
        )]) {
          sh '''
            set -eu
            ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
            REGISTRY=$ACCOUNT.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com

            aws ecr get-login-password | docker login --username AWS --password-stdin $REGISTRY

            docker tag $APP:$BUILD_NUMBER $REGISTRY/$APP:$BUILD_NUMBER
            docker tag $APP:latest       $REGISTRY/$APP:latest
            docker push $REGISTRY/$APP:$BUILD_NUMBER
            docker push $REGISTRY/$APP:latest
          '''
        }
      }
    }

    stage('Deploy to ECS') {
      when {
        branch 'main'
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'aws-jenkins',
          usernameVariable: 'AWS_ACCESS_KEY_ID',
          passwordVariable: 'AWS_SECRET_ACCESS_KEY',
        )]) {
          sh '''
            set -eu
            aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment
            aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
            echo "deployed"
          '''
        }
      }
    }
  }

  post {
    always {
      sh 'docker image prune -f || true'
    }
  }
}
