FROM node:20-alpine

ARG BUILD_VERSION=local-dev

LABEL org.opencontainers.image.title="node-app" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.description="Zero-dependency Node.js app deployed by Jenkins to AWS EC2"

ENV BUILD_VERSION=${BUILD_VERSION} \
    NODE_ENV=production \
    PORT=3000

WORKDIR /usr/src/app

COPY package.json ./
COPY server.js ./
COPY test ./test

RUN mkdir -p /usr/src/app \
    && adduser -D -u 1001 appuser \
    && chown -R appuser:appuser /usr/src/app

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://127.0.0.1:3000/health || exit 1

CMD ["node", "server.js"]
