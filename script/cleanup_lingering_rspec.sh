#!/usr/bin/env bash
set -u

rspec_pids() {
  ps -eo pid=,args= | awk '$2 ~ /\/bin\/rspec$/ { print $1 }'
}

rspec_pids | xargs -r kill -TERM

for _attempt in 1 2 3 4 5; do
  [ -z "$(rspec_pids)" ] && break
  sleep 1
done

rspec_pids | xargs -r kill -KILL
printf '%s\n' 'rspec-cleanup-ok'
