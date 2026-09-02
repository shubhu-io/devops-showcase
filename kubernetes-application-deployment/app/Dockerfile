FROM node:20-alpine

WORKDIR /app
COPY package.json server.js ./

# No npm install — zero dependencies. Validate syntax at build time.
RUN node --check server.js

ENV NODE_ENV=production
ENV PORT=3000
EXPOSE 3000

# Run as non-root
RUN adduser -D -u 10001 appuser && chown -R appuser:appuser /app
USER appuser

HEALTHCHECK --interval=15s --timeout=3s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
