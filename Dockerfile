# --- Multi-Stage Build for SupoClips on HF Spaces ---

# Stage 1: Build Frontend
FROM node:20-slim AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package.json frontend/pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY frontend .
# Disable telemetry and build
ENV NEXT_TELEMETRY_DISABLED 1
RUN pnpm build

# Stage 2: Final Image
FROM python:3.11-slim
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    ffmpeg \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Deno (required by backend)
RUN curl -fsSL https://deno.land/x/install/install.sh | sh
ENV DENO_INSTALL="/root/.deno"
ENV PATH="$DENO_INSTALL/bin:$PATH"

# Install Python dependencies manager (uv)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.cargo/bin:$PATH"

# Copy Backend and install dependencies
COPY backend /app/backend
WORKDIR /app/backend
RUN uv sync --all-groups

# Copy Frontend build from Stage 1
COPY --from=frontend-builder /app/frontend/.next /app/frontend/.next
COPY --from=frontend-builder /app/frontend/public /app/frontend/public
COPY --from=frontend-builder /app/frontend/package.json /app/frontend/package.json
COPY --from=frontend-builder /app/frontend/node_modules /app/frontend/node_modules

# Copy Nginx config
COPY nginx.conf /etc/nginx/sites-available/default

# Copy Entrypoint script
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expose the port HF expects
EXPOSE 7860

# Start everything
ENTRYPOINT ["/app/entrypoint.sh"]
