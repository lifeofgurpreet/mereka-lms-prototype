FROM mcr.microsoft.com/devcontainers/python:3.12-bookworm

# Install Node 18 via NodeSource
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
  && apt-get install -y nodejs \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install system tools
RUN apt-get update && apt-get install -y --no-install-recommends \
  shellcheck \
  shfmt \
  jq \
  curl \
  wget \
  git \
  make \
  ca-certificates \
  gnupg \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
  && apt-get update && apt-get install -y gh \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python tools (as root, into system Python)
RUN pip install --no-cache-dir \
  uv \
  pre-commit \
  "tutor[full]==18.2.2" \
  tutor-mfe==18.1.0 \
  ruff

# Switch to vscode user for remaining setup
USER vscode

# Verify key tools are available
RUN python3 --version \
  && node --version \
  && npm --version \
  && tutor --version \
  && shellcheck --version | head -1
