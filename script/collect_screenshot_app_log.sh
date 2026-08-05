#!/usr/bin/env bash
set -u

log_file="${1:-log/development.log}"

if [ ! -s "$log_file" ]; then
  printf '%s\n' 'screenshots-app-log-empty'
  exit 0
fi

line_count="$(wc -l < "$log_file")"
printf '%s\n' 'screenshots-app-log-collected-ok'
printf 'screenshots-app-log-lines=%s\n' "$line_count"
printf '%s\n' '--- filtered screenshots app log ---'

if ! grep -Eni 'Error|Exception|warning|Warning|Started |Processing by|Completed |Rendered ' "$log_file" | grep -v 'assets/'; then
  printf '%s\n' 'screenshots-app-log-no-matches'
fi

if grep -Eq 'Completed 5[0-9]{2}' "$log_file"; then
  printf '%s\n' 'screenshots-app-log-server-error' >&2
  exit 1
fi
