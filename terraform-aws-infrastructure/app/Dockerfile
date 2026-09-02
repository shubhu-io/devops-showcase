# Minimal Node 20 image (Alpine is small)
FROM node:20-alpine

# We are intentionally not using npm install - the app has ZERO dependencies.

WORKDIR /app

# Copy only what is needed - smaller image, better layer caching
COPY package.json server.js ./

# Runtime config
ENV NODE_ENV=production
ENV PORT=3000

# The app listens on 3000
EXPOSE 3000

# Health check: hit /health with Node's built-in fetch (Node 18+). No curl needed.
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
