# syntax=docker/dockerfile:1

# ---------- Stage 1: build -------------------------------------------------
# The "builder" stage keeps the runtime lean: we copy the source here and
# could run `npm ci` + a build step (e.g. TypeScript / bundler) without
# polluting the final image. This project has zero dependencies, so this
# stage simply validates the syntax and copies the source forward.
FROM node:22-alpine AS builder
WORKDIR /app

COPY package.json ./
COPY server.js ./
COPY src ./src

# Syntax check runs at image build time — a broken server.js fails the build.
RUN node --check server.js && node --check src/routes.js

# ---------- Stage 2: runtime ----------------------------------------------
FROM node:22-alpine AS runtime
ENV NODE_ENV=production
WORKDIR /app

# Copy only what is needed to run, not the build tooling from stage 1.
COPY --from=builder --chown=node:node /app/package.json ./
COPY --from=builder --chown=node:node /app/server.js ./
COPY --from=builder --chown=node:node /app/src ./src

# Run as a non-root user. The node image ships a `node` user for this purpose.
USER node

EXPOSE 3000

# Alpine ships wget (busybox) — use it for the health check.
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -q -O - http://127.0.0.1:3000/health > /dev/null || exit 1

CMD ["node", "server.js"]
