# Stage 1: Install dependencies and build
FROM node:20-slim AS builder
WORKDIR /app

COPY package.json package-lock.json ./
ENV HUSKY=0
RUN npm ci

COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN npm run build

# Keep @next/bundle-analyzer available for runtime (next.config.js requires it)
RUN node -e 'const p=require("./package.json");p.dependencies["@next/bundle-analyzer"]=p.devDependencies["@next/bundle-analyzer"];delete p.devDependencies;require("fs").writeFileSync("package.json",JSON.stringify(p,null,2))' && npm prune --omit=dev

# Stage 2: Production runner
FROM node:20-slim AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder /app/package.json ./
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/tsconfig.json ./
COPY --from=builder /app/i18nConfig.js ./

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl --fail http://localhost:3000/ || exit 1

CMD ["npm", "start"]
