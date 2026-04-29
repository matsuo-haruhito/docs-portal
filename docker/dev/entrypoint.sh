#!/bin/sh
set -e

echo "Waiting for database..."
until pg_isready -h "${DATABASE_HOST:-db}" -p "${DATABASE_PORT:-5432}" -U "${DATABASE_USER:-postgres}" >/dev/null 2>&1; do
  sleep 1
done

echo "Database is ready."

rm -f /app/tmp/pids/server.pid

bundle check || bundle install

if [ -f bin/rails ]; then
  bundle exec rails db:prepare
fi

exec "$@"
