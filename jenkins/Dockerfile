FROM jenkins/jenkins:lts-jdk17

# Plugins the employee-api pipeline needs: declarative pipeline, git SCM
# polling, and the file/string credential bindings used by withCredentials.
USER jenkins
RUN jenkins-plugin-cli --plugins \
      workflow-aggregator \
      git \
      credentials-binding \
      plain-credentials \
      pipeline-stage-view \
      timestamper \
      ws-cleanup

# Build tooling. Runs as root because the pipeline talks to the host Docker
# socket, which is root-owned; see jenkins/docker-compose.yml.
# NB: docker-cli, not docker.io -- on Debian 13 the latter ships only dockerd,
# and we drive the host daemon through the mounted socket rather than running
# a daemon in here.
USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends docker-cli curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

# Both downloads follow the build platform instead of assuming x86_64, so the
# image works on arm64 agents as well.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
      amd64) AWS_ARCH=x86_64; TF_ARCH=amd64 ;; \
      arm64) AWS_ARCH=aarch64; TF_ARCH=arm64 ;; \
      *) echo "unsupported arch: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscli.zip; \
    unzip -q /tmp/awscli.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscli.zip; \
    curl -sSL "https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_${TF_ARCH}.zip" -o /tmp/tf.zip; \
    unzip -q /tmp/tf.zip -d /usr/local/bin; \
    rm /tmp/tf.zip; \
    terraform version; \
    aws --version
