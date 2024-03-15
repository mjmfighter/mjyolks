#!/usr/bin/env bash

# Wrapper around entrypoint.sh.  This just copies logs/latest.log.0 to logs/latest.log.1, and logs/latest.log to logs/latest.log.0, then runs entrypoint.sh.

set -e

cd /home/container || exit 1

if [ -f logs/latest.log.0 ]; then
  cp logs/latest.log.0 logs/latest.log.1
fi
if [ -f logs/latest.log ]; then
  cp logs/latest.log logs/latest.log.0
fi

exec /entrypoint.sh "$@"
