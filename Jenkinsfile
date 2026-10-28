// Jenkins owns the application: build, test, push, roll out.
// Terraform (the infrastructure) is owned by GitHub Actions - see
// .github/workflows/terraform.yml - so the two never fight over state.
//
// AWS access comes from the SSO profile in the mounted ~/.aws, set via
// AWS_PROFILE in jenkins/docker-compose.yml. Refresh it on the host with
//   aws sso login --profile AdministratorAccess-743737183475
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
    stage('Preflight') {
      steps {
        sh '''
          set -eu
          if ! aws sts get-caller-identity --query Arn --output text; then
            echo ""
            echo "AWS credentials are not usable inside the container."
            echo "The SSO session has most likely expired. On the host run:"
            echo "  aws sso login --profile $AWS_PROFILE"
            exit 1
          fi
        '''
      }
    }

    stage('Build') {
      steps {
        sh 'docker build -t $APP:$BUILD_NUMBER -t $APP:latest .'
      }
    }

    stage('Test') {
      steps {
        sh '''
          set -eu

          # app imports cleanly
          docker run --rm $APP:latest python -c "import main; print('import ok')"

          # Then exercise it against a real Postgres on a throwaway network,
          # mirroring the sidecar in the ECS task. Without a database the app
          # blocks in startup retrying the connection, so a bare container
          # would never answer /health anyway.
          NET=smoke-$BUILD_NUMBER
          PG=smoke-pg-$BUILD_NUMBER
          API=smoke-api-$BUILD_NUMBER

          cleanup() {
            docker rm -f "$API" "$PG" >/dev/null 2>&1 || true
            docker network rm "$NET" >/dev/null 2>&1 || true
          }
          trap cleanup EXIT

          docker network create "$NET" >/dev/null

          docker run -d --name "$PG" --network "$NET" \
            -e POSTGRES_DB=appdb \
            -e POSTGRES_USER=appuser \
            -e POSTGRES_PASSWORD=smoketest \
            postgres:16-alpine >/dev/null

          docker run -d --name "$API" --network "$NET" \
            -e DB_HOST="$PG" \
            -e DB_NAME=appdb \
            -e DB_USER=appuser \
            -e DB_PASSWORD=smoketest \
            $APP:latest >/dev/null

          # Probe from inside the container: Jenkins is a sibling, so its
          # localhost is not the app's, and the network is internal.
          probe="import sys, json, urllib.request
try:
    body = urllib.request.urlopen('http://127.0.0.1:8000/' + sys.argv[1], timeout=3).read()
except Exception as exc:
    print(exc)
    sys.exit(1)
print(body.decode()[:200])"

          ok=0
          for i in $(seq 1 45); do
            if docker exec "$API" python -c "$probe" health >/dev/null 2>&1; then
              ok=1
              break
            fi
            sleep 2
          done

          if [ "$ok" -ne 1 ]; then
            echo "health never passed"
            docker logs "$API"
            exit 1
          fi
          echo "health ok"

          # The seeded rows prove ensure_schema() ran against the database.
          docker exec "$API" python -c "$probe" employees
          echo "employees ok"
        '''
      }
    }

    stage('Push to ECR') {
      steps {
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

    stage('Deploy to ECS') {
      steps {
        sh '''
          set -eu
          aws ecs update-service --cluster $CLUSTER --service $SERVICE --force-new-deployment >/dev/null
          echo "waiting for the service to stabilise"
          aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE
          echo "deployed"
        '''
      }
    }
  }

  post {
    always {
      sh 'docker image prune -f || true'
    }
  }
}
