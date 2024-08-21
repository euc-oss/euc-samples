FROM mcr.microsoft.com/devcontainers/base:bookworm
RUN apt-get update && \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get -y install \
        python3 \
        python3-pip && \
    apt clean && \
    rm -rf /usr/lib/python3.11/EXTERNALLY-MANAGED
