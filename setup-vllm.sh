#!/bin/bash
set -e
DIR="${DIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )}"
source .env-hf-token

#git clone git@github.com:kedify/otel-add-on.git || true
cd otel-add-on/examples/vllm
./setup.sh

ONLY_SETUP="true" ./sidecar/setup.sh
# ${DIR}/scraping-router/setup.sh
# ${DIR}/dcgm/setup.sh
