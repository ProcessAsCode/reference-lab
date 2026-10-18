#!/usr/bin/env bash
# Create .env from .env.example with a fresh random value for every secret.
# Never overwrites an existing .env.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  echo ".env already exists; leaving it unchanged." >&2
  exit 0
fi

gen() { openssl rand -hex "${1:-24}"; }

while IFS= read -r line; do
  case "$line" in
    *=__GENERATE_HEX32__) echo "${line%%=*}=$(gen 32)" ;;
    *=__GENERATE__)       echo "${line%%=*}=$(gen 24)" ;;
    *)                    echo "$line" ;;
  esac
done < .env.example > .env
chmod 600 .env
echo "Created .env with generated secrets. Set LLM_GATEWAY_URL, LLM_API_KEY and LLM_MODEL before starting."
