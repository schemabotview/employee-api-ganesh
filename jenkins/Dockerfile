FROM jenkins/jenkins:lts-jdk17
USER root

# docker CLI so the pipeline can build and push against the mounted socket.
# docker-cli, not docker.io: on Debian 13 the client moved into its own
# package and docker.io ships only the daemon, which this container does not
# need or run.
RUN apt-get update \
 && apt-get install -y --no-install-recommends docker-cli curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && docker --version

RUN curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscli.zip \
 && unzip -q /tmp/awscli.zip -d /tmp \
 && /tmp/aws/install \
 && rm -rf /tmp/aws /tmp/awscli.zip

USER jenkins

# Plugins baked in, so the container starts ready instead of needing the
# setup wizard's plugin picker.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Configuration as Code: the admin user and the pipeline job are declared in
# casc.yaml rather than clicked together in the UI.
#
# Deliberately NOT under /var/jenkins_home - compose mounts a volume there,
# which would shadow the file and leave Jenkins failing to boot with
# "not supported by any registered configuration fetcher or does not exist".
COPY casc.yaml /var/jenkins_casc/casc.yaml
ENV CASC_JENKINS_CONFIG=/var/jenkins_casc/casc.yaml
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
