#!/bin/bash
set -xe
DIR="${DIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )}"

source ${DIR}/.env-azure

git clone git@github.com:vllm-project/production-stack.git || true
cd ${DIR}/production-stack/deployment_on_cloud/azure
./entry_point.sh setup

echo "To delete the cluster, run ${DIR}/production-stack/deployment_on_cloud/azure/entry_point.sh cleanup"
# to delete
# ./entry_point.sh cleanup

# now continue w/ https://github.com/kedify/otel-add-on/blob/main/examples/vllm/setup.sh
