FROM ghcr.io/kithlo-server/worker:latest

WORKDIR /actions-runner

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    jq \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

RUN curl -o actions-runner-linux-arm-2.338.2.tar.gz -L https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-linux-arm-2.338.2.tar.gz && \
    echo "9677d6171f2c60040efc9111c4e7dd34fdd714cd7b24b171a7925eba7d09c5fa  actions-runner-linux-arm-2.338.2.tar.gz" | shasum -a 256 -c && \
    tar xzf ./actions-runner-linux-arm-2.338.2.tar.gz

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
