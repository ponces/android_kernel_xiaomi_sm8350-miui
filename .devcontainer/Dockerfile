FROM ubuntu:24.04

USER root

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y bc bison build-essential clang curl flex git jq libssl-dev lld llvm python3 python-is-python3 zip zstd && \
    apt-get clean -y && \
    apt-get autoremove -y && \
    rm -rf /var/lib/apt/lists/*

USER ubuntu
WORKDIR /workspaces

RUN mkdir -p /workspaces/output
