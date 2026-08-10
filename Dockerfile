# syntax=docker/dockerfile:1

# ============================================================
# Stage 1: base — Ruby + system dependencies
# ============================================================
FROM ruby:4.0.2-alpine3.23 AS base

RUN apk update && apk add --no-cache \
    postgresql-client \
    yaml-dev \
    tzdata \
    shared-mime-info \
    vips \
    nodejs \
    npm \
    git \
    bash

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_PATH="/usr/local/bundle"

WORKDIR /app

# ============================================================
# Stage 2: build — compile gems + frontend assets
# ============================================================
FROM base AS build

RUN apk add --no-cache \
    build-base \
    postgresql-dev \
    vips-dev

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install --jobs 4 --retry 3 && \
    rm -rf "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install npm packages
COPY package.json package-lock.json ./
RUN npm ci --production=false

# Copy application code
COPY . .

# Build frontend assets via Vite
RUN SECRET_KEY_BASE=dummy-for-assets bin/rails assets:precompile

# Remove dev/test artifacts from the build image
RUN rm -rf node_modules tmp/cache spec test .git docker .github docs-src

# ============================================================
# Stage 3: production — minimal runtime image
# ============================================================
FROM base AS production

# Create non-root user
RUN addgroup -g 1000 rails && \
    adduser -S -u 1000 -G rails rails

COPY --from=build --chown=rails:rails /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /app /app

USER rails

# Precompiled bootsnap cache
RUN bin/rails bootsnap:precompile

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD wget -qO- http://localhost:3000/up || exit 1

ENTRYPOINT ["bin/rails"]
CMD ["server", "-b", "0.0.0.0"]
