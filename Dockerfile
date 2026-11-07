FROM ghcr.io/kithlo-server/worker:latest

WORKDIR /actions-runner

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    jq \
    && install -m 0755 -d /etc/apt/keyrings \
    # Docker
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null \
    # GitHub CLI
    && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | \
    tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    # APT install
    && apt-get update \
    && apt-get install -y \
    gh \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN curl -o actions-runner-linux-arm64-2.338.2.tar.gz -L https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-linux-arm64-2.338.2.tar.gz && \
    echo "670adb2f268fe21dcbb58b3db0e0aa9d5b3bddfe2c651481336e561ff86de945  actions-runner-linux-arm64-2.338.2.tar.gz" | shasum -a 256 -c && \
    tar xzf ./actions-runner-linux-arm64-2.338.2.tar.gz && \
    bash ./bin/installdependencies.sh

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
