FROM node:20-alpine

WORKDIR /app

# Dependencies first — layer caches unless package*.json changes, so a code
# edit doesn't force a full npm install on every rebuild.
COPY package*.json ./
RUN npm ci --omit=dev

COPY src ./src

ENV NODE_ENV=production
EXPOSE 3001

# Container-level health check — matches render.yaml's healthCheckPath.
# Bare node instead of curl/wget: neither is installed on node:alpine and
# adding one just for this is unnecessary weight in the image.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD node -e "require('http').get('http://localhost:' + (process.env.PORT || 3001) + '/api/health', r => process.exit(r.statusCode === 200 ? 0 : 1)).on('error', () => process.exit(1))"

# Not root — node:alpine ships an unprivileged 'node' user for exactly this.
USER node

CMD ["node", "src/app.js"]
