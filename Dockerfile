ARG DOCKER_VER=19.03.13
FROM docker:${DOCKER_VER} as docker

FROM ubuntu:20.04

# No interactive frontend during docker build
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true

# Note for selenium testing: Firefox is installed for its deps, but then
# removed so downstream builds can select their own version.

RUN apt-get update && apt-get -y --no-install-recommends install \
    apt-transport-https\
    build-essential\
    curl\
    firefox\
    git\
    git-lfs\
    gnupg\
    jq\
    libdbus-glib-1-2\
    libgtk-3.0\
    liblzma-dev\
    libxt6\
    openjdk-11-jdk\
    openssh-server\
    python\
    python-dev\
    python-setuptools\
    python-pip-whl\
    python3\
    python3-dev\
    python3-pip\
    python3-setuptools\
    python3-wheel\
    locales\
    unzip\
    zip\
    && apt-get -y purge firefox\
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*\
    && sed -i 's/securerandom\.source=file:\/dev\/random/securerandom\.source=file:\/dev\/urandom/' /usr/lib/jvm/java-11-openjdk-amd64/conf/security/java.security

ARG BAZELISK_VER=1.7.4
ARG NODE_VER=node_12.x

# Set up apt repos
RUN curl -sL https://storage.googleapis.com/bazel-apt/doc/apt-key.pub.gpg | apt-key add - &&\
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" >/etc/apt/sources.list.d/bazel.list &&\
    curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - &&\
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list &&\
    curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - &&\
    echo "deb https://deb.nodesource.com/${NODE_VER} focal main" > /etc/apt/sources.list.d/nodesource.list &&\
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" >/etc/apt/sources.list.d/yarn.list

# Install packages
RUN curl -sL "https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VER}/bazelisk-linux-amd64" -o /usr/local/bin/bazel && chmod +x /usr/local/bin/bazel\
    && apt update && apt install -y\
    kubectl\
    nodejs\
    yarn\
    && rm -rf /var/lib/apt/lists/*\
    && npm install -g typescript

# Install docker cli only
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker

ARG MAVEN_VER=3.6.3
ARG MAVEN_SHA=c35a1803a6e70a126e80b2b3ae33eed961f83ed74d18fcd16909b2d44d7dada3203f1ffe726c17ef8dcca2dcaa9fca676987befeadc9b9f759967a8cb77181c0
ARG MAVEN_BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VER}/binaries

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${MAVEN_BASE_URL}/apache-maven-${MAVEN_VER}-bin.tar.gz \
  && echo "${MAVEN_SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven

# Install https://helm.sh/
ARG HELM_VER=3.4.0
ARG HELM_URL=https://get.helm.sh/helm-v${HELM_VER}-linux-amd64.tar.gz

RUN mkdir -p /opt/helm \
  && curl -sSL ${HELM_URL} | tar -C /opt/helm --strip-components=1 -xzf - \
  && ln -s /opt/helm/helm /usr/bin/helm

# Configuring the locale enables bazel's autocompletion
RUN locale-gen en_GB.UTF-8 &&\
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales 2>/dev/null

# Create a service user with UID matching jenkins/jnlp-slave image to simplify k8s-based builds
RUN adduser --system --home /home/jenkins --uid 10000 jenkins
