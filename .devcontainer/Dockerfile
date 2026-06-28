FROM mcr.microsoft.com/devcontainers/python:3

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    dnsutils \
    htop \
    jq \
    less \
    net-tools \
    postgresql-client \
    tree \
    wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install micro text editor
RUN curl https://getmic.ro | bash && mv micro /usr/local/bin/
