ARG DOCKER_VER=26.0.0-cli
FROM docker.io/docker:${DOCKER_VER} as docker

FROM docker.io/ubuntu:22.04

# No interactive frontend during docker build
ARG DEBIAN_FRONTEND=noninteractive
ARG DEBCONF_NONINTERACTIVE_SEEN=true

RUN apt-get update && apt-get -y --no-install-recommends install \
    apt-transport-https\
    build-essential\
    ca-certificates\
    curl\
    git\
    git-lfs\
    gnupg\
    jq\
    libatk-bridge2.0-0\
    libgbm1\
    libgtk-3-0\
    locales\
    openjdk-21-jdk\
    unzip\
    xvfb\
    xz-utils\
    zip\
    zstd\
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

ARG SHELLCHECK_VER=v0.10.0
ARG BAZELISK_VER=1.19.0
ARG KUBERNETES_VER=1.29
ARG NODE_VER=20.x

# Set up apt repos
RUN curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >/etc/apt/keyrings/bazel-archive-keyring.gpg &&\
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" >/etc/apt/sources.list.d/bazel.list &&\
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg &&\
    echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${KUBERNETES_VER}/deb/ /" >/etc/apt/sources.list.d/kubernetes.list &&\
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg &&\
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_VER} nodistro main" >/etc/apt/sources.list.d/nodesource.list &&\
    # N|solid Config
    echo "Package: nsolid" >/etc/apt/preferences.d/nsolid &&\
    echo "Pin: origin deb.nodesource.com" >>/etc/apt/preferences.d/nsolid &&\
    echo "Pin-Priority: 600" >>/etc/apt/preferences.d/nsolid &&\
    # Nodejs Config
    echo "Package: nodejs" >/etc/apt/preferences.d/nodejs &&\
    echo "Pin: origin deb.nodesource.com" >>/etc/apt/preferences.d/nodejs &&\
    echo "Pin-Priority: 600" >>/etc/apt/preferences.d/nodejs

# Install packages
RUN curl -sL "https://github.com/bazelbuild/bazelisk/releases/download/v${BAZELISK_VER}/bazelisk-linux-amd64" -o /usr/local/bin/bazel && chmod +x /usr/local/bin/bazel\
    && curl -sL "https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VER}/shellcheck-${SHELLCHECK_VER}.linux.x86_64.tar.xz" | tar -xJ && mv shellcheck-${SHELLCHECK_VER}/shellcheck /usr/local/bin/shellcheck && rm -rf shellcheck-${SHELLCHECK_VER}\
    && apt update && apt install -y\
    kubectl\
    nodejs\
    && rm -rf /var/lib/apt/lists/*\
    && npm install -g typescript yarn pnpm

# Install docker cli only
COPY --from=docker /usr/local/bin/docker /usr/local/bin/docker

# Install https://helm.sh/
ARG HELM_VER=3.14.3
ARG HELM_URL=https://get.helm.sh/helm-v${HELM_VER}-linux-amd64.tar.gz

RUN mkdir -p /opt/helm \
  && curl -sSL ${HELM_URL} | tar -C /opt/helm --strip-components=1 -xzf - \
  && ln -s /opt/helm/helm /usr/bin/helm

# Configuring the locale enables bazel's autocompletion
RUN locale-gen en_GB.UTF-8 &&\
    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure locales 2>/dev/null

# Create a service user with UID matching jenkins/jnlp-slave image to simplify k8s-based builds
RUN addgroup --system --gid 1000 jenkins \
  && adduser --system --home /home/jenkins --uid 1000 --gid 1000 jenkins
