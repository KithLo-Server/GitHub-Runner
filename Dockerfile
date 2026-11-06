FROM ghcr.io/kithlo-server/worker:latest

WORKDIR /actions-runner

RUN curl -o actions-runner-linux-arm-2.338.2.tar.gz -L https://github.com/actions/runner/releases/download/v2.338.2/actions-runner-linux-arm-2.338.2.tar.gz && \
    echo "9677d6171f2c60040efc9111c4e7dd34fdd714cd7b24b171a7925eba7d09c5fa  actions-runner-linux-arm-2.338.2.tar.gz" | shasum -a 256 -c && \
    tar xzf ./actions-runner-linux-arm-2.338.2.tar.gz

COPY --chmod=0755 entrypoint.sh /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
