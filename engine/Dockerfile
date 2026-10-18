# UAPF reference runtime (UAPFormat/uapf-engine), built from the checkout
# that scripts/fetch-components.sh places in components/uapf-engine.
# Build context: components/uapf-engine

FROM node:20-bookworm-slim AS builder
WORKDIR /build
COPY . .
RUN npm ci --no-audit --no-fund && npx tsc -p tsconfig.json && npm prune --omit=dev

FROM node:20-bookworm-slim
ENV NODE_ENV=production PORT=4000 PACKAGES_DIR=/packages
WORKDIR /app
COPY --from=builder /build/dist ./dist
COPY --from=builder /build/node_modules ./node_modules
COPY --from=builder /build/package.json ./package.json
COPY --from=builder /build/public ./public
RUN mkdir -p /packages /app/.cache /app/sessions && chown -R node:node /app
USER node
EXPOSE 4000
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=5 \
  CMD node -e "require('http').get('http://localhost:4000/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"
CMD ["node", "dist/http/server.js"]
