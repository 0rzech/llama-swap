#!/bin/bash

set -euo pipefail

echo '==========='
echo ' LLAMA.CPP '
echo '==========='

/app/llama-server --version

echo '============'
echo ' LLAMA-SWAP '
echo '============'

/app/llama-swap --version

exec /app/llama-swap "${@:1}"
