ARG IMAGE_REGISTRY=docker.io
ARG IMAGE_BASE=${IMAGE_REGISTRY}/almalinux/10-minimal:latest

FROM ${IMAGE_BASE} AS builder

ARG LLAMA_SWAP_VERSION=154
ARG LLAMA_CPP_VERSION=6248

RUN <<EOF
    set -euo pipefail
    microdnf upgrade --assumeyes --setopt=install_weak_deps=0
    microdnf install --assumeyes --setopt=install_weak_deps=0 gzip tar unzip
    microdnf clean all
    curl --proto '=https' --location --proto-redir '=https' --max-redirs 1 "https://github.com/mostlygeek/llama-swap/releases/download/v${LLAMA_SWAP_VERSION}/llama-swap_${LLAMA_SWAP_VERSION}_linux_amd64.tar.gz" --output 'llama-swap.tar.gz'
    mkdir 'llama-swap'
    tar --extract --verbose --file 'llama-swap.tar.gz' --directory 'llama-swap'
    rm --verbose llama-swap/LICENSE* llama-swap/README*
    curl --proto '=https' --location --proto-redir '=https' --max-redirs 1 "https://github.com/ggml-org/llama.cpp/releases/download/b${LLAMA_CPP_VERSION}/llama-b${LLAMA_CPP_VERSION}-bin-ubuntu-vulkan-x64.zip" --output 'llama.cpp.zip'
    unzip -t 'llama.cpp.zip'
    unzip -d 'llama.cpp' -o 'llama.cpp.zip'
    rm --verbose llama.cpp/build/bin/LICENSE*
EOF

FROM ${IMAGE_BASE}

COPY start.sh /app/

ARG LLAMA_SWAP_VERSION=154
LABEL llama-swap-version="${LLAMA_SWAP_VERSION}"
COPY --from=builder /llama-swap/* /app/

ARG LLAMA_CPP_VERSION=6248
LABEL llama-cpp-version="${LLAMA_CPP_VERSION}"
LABEL llama-cpp-backend=vulkan
COPY --from=builder /llama.cpp/build/bin/* /app/

RUN <<EOF
    set -euo pipefail
    microdnf upgrade --assumeyes --setopt=install_weak_deps=0
    microdnf install --assumeyes --setopt=install_weak_deps=0 libgomp shadow-utils vulkan-devel
    passwd --delete root
    usermod --expiredate 1 root
    useradd --user-group --create-home llama
    mkdir --parents '/home/llama/.cache/llama.cpp'
    chown --recursive llama:llama '/home/llama'
    microdnf remove --assumeyes shadow-utils
    microdnf clean all
EOF

WORKDIR /app

USER llama

HEALTHCHECK CMD ["/usr/bin/curl", "--silent", "--show-error", "--fail", "http://localhost:8080/health"]

ENTRYPOINT ["/app/start.sh"]
CMD ["-config", "/app/config.yaml"]

ARG CONFIG_VARIANT=example
COPY config.${CONFIG_VARIANT}.yaml /app/config.yaml
