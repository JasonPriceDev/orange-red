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

# Install latest stable Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install GitHub Copilot CLI
RUN npm install -g @githubnext/github-copilot-cli

# Install micro text editor
RUN curl https://getmic.ro | bash && mv micro /usr/local/bin/
