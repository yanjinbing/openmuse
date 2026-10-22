# syntax=docker/dockerfile:1

FROM 01ai-registry.cn-shanghai.cr.aliyuncs.com/01-ai/mix/node:24-bookworm AS build

WORKDIR /app
RUN npm install --global pnpm@11.19.0

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY patches ./patches
COPY apps/mobile/package.json ./apps/mobile/package.json
COPY apps/worker/package.json ./apps/worker/package.json
COPY apps/worker/package-lock.json ./apps/worker/package-lock.json
RUN pnpm install --frozen-lockfile

COPY tsconfig.json tsconfig.build.json biome.json ./
COPY apps ./apps
COPY packages ./packages

ARG EXPO_PUBLIC_API_URL=/
ENV EXPO_PUBLIC_API_URL=${EXPO_PUBLIC_API_URL}

RUN pnpm build:server \
  && pnpm --dir apps/mobile exec expo export \
    --platform web \
    --output-dir dist/web \
    --clear

FROM 01ai-registry.cn-shanghai.cr.aliyuncs.com/01-ai/mix/node:24-bookworm AS runtime

WORKDIR /app

# Use Aliyun's Debian mirror for faster package installation in mainland China.
RUN if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
      sed -i \
        -e 's|deb.debian.org/debian|mirrors.aliyun.com/debian|g' \
        -e 's|security.debian.org/debian-security|mirrors.aliyun.com/debian-security|g' \
        /etc/apt/sources.list.d/debian.sources; \
    else \
      sed -i \
        -e 's|deb.debian.org/debian|mirrors.aliyun.com/debian|g' \
        -e 's|security.debian.org/debian-security|mirrors.aliyun.com/debian-security|g' \
        /etc/apt/sources.list; \
    fi \
  && apt-get update \
  && apt-get install --yes --no-install-recommends nginx \
  && rm -rf /var/lib/apt/lists/* \
  && rm -f /etc/nginx/sites-enabled/default

ENV NODE_ENV=production \
    HOST=127.0.0.1 \
    PORT=8788 \
    DATA_DIR=/var/data/openmuse

COPY --from=build /app/package.json ./package.json
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/apps/mobile/dist/web ./web
COPY --from=build /app/apps/computer/files.py ./apps/computer/files.py

RUN printf '%s\n' \
  'worker_processes auto;' \
  'error_log /var/log/nginx/error.log warn;' \
  'pid /tmp/nginx.pid;' \
  'events {' \
  '  worker_connections 1024;' \
  '}' \
  'http {' \
  '  include /etc/nginx/mime.types;' \
  '  default_type application/octet-stream;' \
  '  access_log /var/log/nginx/access.log;' \
  '  sendfile on;' \
  '  client_max_body_size 12m;' \
  '  server {' \
  '    listen 8787;' \
  '    server_name _;' \
  '    location ~ ^/api(?:/|$) {' \
  '      proxy_pass http://127.0.0.1:8788;' \
  '      proxy_http_version 1.1;' \
  '      proxy_buffering off;' \
  '      proxy_read_timeout 1h;' \
  '      proxy_send_timeout 1h;' \
  '      proxy_set_header Host $host;' \
  '      proxy_set_header X-Real-IP $remote_addr;' \
  '      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;' \
  '      proxy_set_header X-Forwarded-Proto $scheme;' \
  '    }' \
  '    location / {' \
  '      root /app/web;' \
  '      try_files $uri $uri/ /index.html;' \
  '    }' \
  '  }' \
  '}' > /etc/nginx/nginx.conf




# Defaults from .env.e2b; override at run time with --env-file.
# WARNING: these secrets are baked into the image.
ENV E2B_DOMAIN=sandbox.airacloud.com \
    COMPUTER_ENABLED=true \
    COMPUTER_PROVIDER=e2b-desktop \
    COMPUTER_E2B_TEMPLATE=e2b_desktop \
    COMPUTER_DEPLOYMENT_ID=openmuse-e2b-local \
    OPENAI_BASE_URL=https://api-token-internal.airacloud.cn/v1 \
    MODEL=openai/deepseek-v4-1-flash \
    OPENAI_CHAT_COMPLETIONS=true \
    WORKSPACE_MODE=sample \
    AGENT_BACKEND=model \
    RICH_THREADS=false \
    TOKEN_ENCRYPTION_KEY=Q4JRfFRIwK2DWPNw3Ooy+FvmRSk/3RDGdxz47CDmVoA= \
    WORKER_TOKEN=local-9d6699dfa9f30543683f6e7fd47a55562e1a40b15bca054b \
    PUBLIC_API_URL=http://localhost:8787 \
    ALLOWED_ORIGINS=http://localhost:8787,http://127.0.0.1:8787

EXPOSE 8787

CMD ["bash", "-lc", "node dist/apps/server/src/index.js & api=$!; nginx -g 'daemon off;' & nginx_pid=$!; wait -n $api $nginx_pid; status=$?; kill $api $nginx_pid 2>/dev/null || true; exit $status"]
