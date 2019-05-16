FROM ubuntu:18.04

RUN apt-get update && apt-get install -y\
    apt-transport-https\
    build-essential\
    curl\
    git\
    libdbus-glib-1-2\
    libgtk-3.0\
    liblzma-dev\
    libxt6\
    openjdk-8-jdk\
    openssh-server\
    python\
    python-pip\
    locales\
    && rm -rf /var/lib/apt/lists/*

ENV BAZEL_VER 0.25.2
ENV NODE_VER node_10.x

# Set up apt repos
RUN curl -sL https://storage.googleapis.com/bazel-apt/doc/apt-key.pub.gpg | apt-key add - &&\
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" >/etc/apt/sources.list.d/bazel.list &&\
    curl -sL https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - &&\
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list &&\
    curl -sL https://download.docker.com/linux/ubuntu/gpg | apt-key add - &&\
    echo "deb [arch=amd64] https://download.docker.com/linux/ubuntu xenial stable" >/etc/apt/sources.list.d/docker.list &&\
    curl -sL https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - &&\
    echo "deb https://deb.nodesource.com/$NODE_VER xenial main" >/etc/apt/sources.list.d/nodejs.list

# Install packages
RUN curl -sLO "https://github.com/bazelbuild/bazel/releases/download/${BAZEL_VER}/bazel_${BAZEL_VER}-linux-x86_64.deb"\
    && apt update && apt install -y\
    docker-ce\
    kubectl\
    nodejs\
    ./bazel_${BAZEL_VER}-linux-x86_64.deb\
    && rm -rf /var/lib/apt/lists/* ./bazel_${BAZEL_VER}-linux-x86_64.deb

# Configuring the locale enables bazel's autocompletion
RUN locale-gen en_GB.UTF-8 &&\
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales 2>/dev/null

# Create a service user with UID matching jenkins/jnlp-slave image to simplify k8s-based builds
RUN adduser --system --home /home/jenkins --uid 10000 jenkins
