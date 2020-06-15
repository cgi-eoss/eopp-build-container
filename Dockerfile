FROM ubuntu:18.04

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
    openjdk-8-jdk\
    openssh-server\
    python\
    python-dev\
    python-pip\
    python-setuptools\
    python-wheel\
    python3\
    python3-dev\
    python3-pip\
    python3-setuptools\
    python3-wheel\
    locales\
    && apt-get -y purge firefox\
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*\
    && sed -i 's/securerandom\.source=file:\/dev\/random/securerandom\.source=file:\/dev\/urandom/' ./usr/lib/jvm/java-8-openjdk-amd64/jre/lib/security/java.security

ARG BAZEL_VER=3.2.0
ARG NODE_VER=node_10.x

# Set up apt repos
RUN curl -sL https://storage.googleapis.com/bazel-apt/doc/apt-key.pub.gpg | apt-key add - &&\
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" >/etc/apt/sources.list.d/bazel.list &&\
    curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - &&\
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list &&\
    curl -sL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &&\
    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable" >/etc/apt/sources.list.d/docker.list &&\
    curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - &&\
    echo "deb https://deb.nodesource.com/$NODE_VER xenial main" >/etc/apt/sources.list.d/nodejs.list &&\
    curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - &&\
    echo "deb https://dl.yarnpkg.com/debian/ stable main" >/etc/apt/sources.list.d/yarn.list

# Install packages
RUN curl -sLO "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VER}/bazel_${BAZEL_VER}-linux-x86_64.deb"\
    && apt update && apt install -y\
    docker-ce\
    kubectl\
    nodejs\
    yarn\
    ./bazel_${BAZEL_VER}-linux-x86_64.deb\
    && rm -rf /var/lib/apt/lists/* ./bazel_${BAZEL_VER}-linux-x86_64.deb\
    && npm install -g typescript

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

# Configuring the locale enables bazel's autocompletion
RUN locale-gen en_GB.UTF-8 &&\
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales 2>/dev/null

# Create a service user with UID matching jenkins/jnlp-slave image to simplify k8s-based builds
RUN adduser --system --home /home/jenkins --uid 10000 jenkins
