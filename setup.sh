#!/bin/bash
set -e
DIR="${DIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )}"

echo "Where do you want to deploy the cluster?"
echo "1: gcp"
echo "2: azure"
echo "3: current k8s context (do not create the cluster)"
while :; do
    read -ep 'Enter your choice: ' number
    [[ $number =~ ^[[:digit:]]+$ ]] || continue
    (( number <= 2 && number >= 1 )) || continue
    break
done

if [ "$number" -eq 1 ]; then
    echo "Deploying to GCP..."
    ${DIR}/setup-cluster-gcp.sh
elif [ "$number" -eq 2 ]; then
    echo "Deploying to Azure..."
    ${DIR}/setup-cluster-azure.sh
fi

${DIR}/setup-vllm.sh
