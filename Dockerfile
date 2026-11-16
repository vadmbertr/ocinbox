
FROM node:22-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git gh curl ca-certificates ripgrep \
       openssh-client less procps \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g @opencode/cli bun

RUN mkdir -p /home/oc/.config/opencode /workspace

RUN curl -fsSL https://xerj.org/get \
    | XERJ_INSTALL_DIR=/usr/local/bin sh

COPY ocxerj /usr/local/bin/ocxerj
RUN chmod +x /usr/local/bin/ocxerj

ENV HOME=/home/oc
ENV LANG=C.UTF-8

WORKDIR /workspace

CMD ["opencode"]
