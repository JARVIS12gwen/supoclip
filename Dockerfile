# Stage 1: Build Frontend
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend

# Install OpenSSL (required by Prisma)
RUN apt-get update && apt-get install -y openssl curl && rm -rf /var/lib/apt/lists/*

# Copy package management files
COPY frontend/package.json frontend/pnpm-lock.yaml* ./

# Copy Prisma schema
COPY frontend/prisma ./prisma/

# Install dependencies
RUN npm install -g pnpm && pnpm install

# Copy the rest of the frontend
COPY frontend .

# Generate Prisma client and build
ENV NEXT_TELEMETRY_DISABLED 1
RUN pnpm build

# Stage 2: Final Image
FROM python:3.11-slim
WORKDIR /app

# Install system dependencies + Node.js
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ffmpeg \
    nginx \
    supervisor \
    openssl \
    redis-server \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Deno
RUN curl -fsSL https://deno.land/x/install/install.sh | sh
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

# Install uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Copy Backend
COPY backend /app/backend
WORKDIR /app/backend
RUN uv sync --all-groups

# Copy Frontend build
WORKDIR /app/frontend
COPY --from=frontend-builder /app/frontend/.next/standalone ./
COPY --from=frontend-builder /app/frontend/.next/static ./.next/static
COPY --from=frontend-builder /app/frontend/public ./public
COPY --from=frontend-builder /app/frontend/src/generated/prisma ./src/generated/prisma
COPY --from=frontend-builder /app/frontend/prisma ./prisma

# Ensure Prisma engine is accessible by copying it to a standard location
RUN mkdir -p /app/frontend/.prisma/client && \
    cp ./src/generated/prisma/libquery_engine-debian-openssl-3.0.x.so.node /app/frontend/.prisma/client/ || true

# Copy configs
COPY nginx.conf /etc/nginx/sites-available/default
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Env vars
ENV PORT 3107
ENV HOSTNAME "0.0.0.0"
ENV NODE_ENV production

# Expose
EXPOSE 7860

ENTRYPOINT ["/app/entrypoint.sh"]


