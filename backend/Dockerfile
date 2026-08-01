# ---------- Stage 1: build ----------
FROM node:22-alpine AS builder

WORKDIR /app

# Prisma needs openssl to generate its query engine on Alpine
RUN apk add --no-cache openssl

COPY package*.json ./
COPY prisma ./prisma/

RUN npm ci

COPY . .

RUN npx prisma generate && npm run build

# ---------- Stage 2: production ----------
FROM node:22-alpine AS production

WORKDIR /app

RUN apk add --no-cache openssl dumb-init

ENV NODE_ENV=production

COPY package*.json ./
COPY prisma ./prisma/

# Only production dependencies land in the final image
RUN npm ci --omit=dev && npx prisma generate && npm cache clean --force

COPY --from=builder /app/dist ./dist

# Running as a non-root user limits the blast radius of a container escape
RUN addgroup -g 1001 -S nodejs && adduser -S nestjs -u 1001 \
    && chown -R nestjs:nodejs /app

USER nestjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/api/v1/health',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

# dumb-init reaps zombie processes and forwards signals for clean shutdowns
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "dist/main"]
