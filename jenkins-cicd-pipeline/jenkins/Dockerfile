# Jenkins controller with Docker CLI installed (Docker-outside-of-Docker pattern).
# https://hub.docker.com/r/jenkins/jenkins
FROM jenkins/jenkins:lts-jdk17

USER root

# Install Docker CLI so the pipeline can talk to the host daemon via the
# mounted /var/run/docker.sock.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates \
       curl \
       gnupg \
       lsb-release \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Node.js so the pipeline can run `node --check` and `node --test` directly
# on the controller (build agents can use node images instead).
RUN apt-get update \
    && apt-get install -y --no-install-recommends nodejs npm \
    && rm -rf /var/lib/apt/lists/*

# Allow the jenkins user to talk to the host docker daemon via the mounted socket.
# (Group ID 999 is the typical host 'docker' group; the container group is
#  added dynamically so the socket permission is honoured.)
RUN groupadd --force --gid 999 docker \
    && usermod -aG docker jenkins

# Install plugins at BUILD time with the official plugin manager. Modern
# jenkins/jenkins images no longer auto-install a bare plugins.txt at boot;
# the plugin manager writes .jpi files into /usr/share/jenkins/ref/plugins,
# which the reference-copy mechanism then seeds into JENKINS_HOME on first boot.
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Remove CASC_JENKINS_CONFIG unset? We keep it simple: JCasC config is mounted
# via docker-compose at /var/jenkins_home/casc_configs/jenkins.yaml.
ENV CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

USER jenkins
