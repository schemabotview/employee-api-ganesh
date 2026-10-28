FROM jenkins/jenkins:lts-jdk17
USER root

# docker CLI so the pipeline can build/push images against the mounted socket
RUN apt-get update \
 && apt-get install -y --no-install-recommends docker.io curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscli.zip \
 && unzip -q /tmp/awscli.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscli.zip

USER jenkins
