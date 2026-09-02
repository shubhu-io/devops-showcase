# https://hub.docker.com/_/node
FROM node:24-alpine

# Run as a non-root user (least privilege)
USER node

WORKDIR /home/node/app

# No npm install needed: the app uses zero external dependencies.
# Copy only what the app needs.
COPY --chown=node:node package.json server.js ./

# Expose the HTTP port (must match PORT in server.js / Jenkinsfile)
EXPOSE 3000

# HEALTHCHECK (uses Node itself so no curl/wget dependency is required)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||3000)+'/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))"

CMD ["node", "server.js"]
