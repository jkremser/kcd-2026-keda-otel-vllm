#!/bin/bash

# for more examples and other integration patterns, check out:
# https://github.com/kedify/otel-add-on/tree/main/examples/vllm

set -e
DIR="${DIR:-$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )}"
source .env-hf-token

command -v figlet &> /dev/null && {
  __wid=$(/usr/bin/tput cols) && _wid=$(( __wid < 155 ? __wid : 155 ))
  figlet -w${_wid} OTel Operator + vLLM stack
}
[ -z "${HF_TOKEN}" ] && echo "Set HF_TOKEN env variable (https://huggingface.co/docs/hub/en/security-tokens)" && exit 1

# make sure your k8s cluster supports GPUs and have at least one accelerator on a node
# following pod should run successfully
# cat <<EOF | kubectl apply -f -
# apiVersion: v1
# kind: Pod
# metadata:
#   name: cuda-vectoradd
# spec:
#   restartPolicy: OnFailure
#   containers:
#   - name: cuda-vectoradd
#     image: "nvcr.io/nvidia/k8s/cuda-sample:vectoradd-cuda11.7.1-ubuntu20.04"
#     resources:
#       limits:
#         nvidia.com/gpu: 1
# EOF


# setup helm repos
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo add kedify https://kedify.github.io/charts
helm repo add vllm https://vllm-project.github.io/production-stack
helm repo update open-telemetry kedify vllm

set -e

# deploy KEDA
KEDA_VERSION=$(curl -s https://api.github.com/repos/kedify/charts/releases | jq -r '[.[].tag_name | select(. | startswith("keda/")) | sub("^keda/"; "")] | first')
KEDA_VERSION=${KEDA_VERSION:-v2.17.1-0}
helm upgrade -i keda kedify/keda --namespace keda --create-namespace --version ${KEDA_VERSION}

# wait for components
for d in \
  keda-operator \
  keda-operator-metrics-apiserver ; do
    kubectl rollout status -n keda --timeout=600s deploy/${d}
  done

# In order for the sidecar approach to work properly, the CertManager needs to also be installed in the k8s cluster. Otherwise, OTel operator will not create the admission webhook correctly.
helm upgrade -i --create-namespace -n cert-manager cert-manager oci://quay.io/jetstack/charts/cert-manager --version v1.18.2 --set crds.enabled=true
kubectl rollout status -n cert-manager --timeout=600s deploy/cert-manager

# install KEDA OTel Scaler & OTel Operator
helm upgrade -i keda-otel-scaler -nkeda oci://ghcr.io/kedify/charts/otel-add-on --version=v0.1.3 \
 -f ${DIR}/otel-scaler-values.yaml \
 -f https://raw.githubusercontent.com/kedify/otel-add-on/refs/heads/main/helmchart/otel-add-on/enable-operator-hooks-values.yaml
kubectl rollout status -n keda --timeout=600s deploy/keda-otel-scaler

# deploy vLLM Stack & model
echo "What model do you want to deploy?"
echo "1: llama3.1-8b-instruct"
echo "2: qwen2.5-7b-instruct-awq"
echo "3: gemma-3-4b-it"
while :; do
    read -ep 'Enter your choice: ' number
    [[ $number =~ ^[[:digit:]]+$ ]] || continue
    (( number <= 3 && number >= 1 )) || continue
    break
done

if [ "$number" -eq 1 ]; then
    echo "Deploying llama..."
    helm upgrade -i vllm vllm/vllm-stack --version 0.1.11 -f ${DIR}/vllm-stack-values-llama.yaml --set "servingEngineSpec.modelSpec[0].hf_token=${HF_TOKEN}"
    kubectl rollout status --timeout=900s deploy/vllm-llama-deployment-vllm
elif [ "$number" -eq 2 ]; then
    echo "Deploying qwen..."
    helm upgrade -i vllm vllm/vllm-stack --version 0.1.11 -f ${DIR}/vllm-stack-values-qwen.yaml --set "servingEngineSpec.modelSpec[0].hf_token=${HF_TOKEN}"
    kubectl rollout status --timeout=900s deploy/vllm-qwen-deployment-vllm
elif [ "$number" -eq 3 ]; then
    echo "Deploying gemma..."
    helm upgrade -i vllm vllm/vllm-stack --version 0.1.11 -f ${DIR}/vllm-stack-values-gemma.yaml --set "servingEngineSpec.modelSpec[0].hf_token=${HF_TOKEN}"
    kubectl rollout status --timeout=900s deploy/vllm-gemma-deployment-vllm
fi

# test
(kubectl port-forward svc/vllm-router-service 30080:80 &> /dev/null)& pf_pid=$!
(sleep $[10*60] && kill ${pf_pid})&

# change the model param accordingly to the model you deployed
for x in {0..5}; do curl -s -X POST http://localhost:30080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4",
    "prompt": "Once upon a time,",
    "max_tokens": 20
  }' | jq '.choices[].text' ; done


sleep .8 && hey -c 60 -z 60s -t 90 -m POST \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "hugging-quants/Meta-Llama-3.1-8B-Instruct-AWQ-INT4",
    "prompt": "Once upon a time,",
    "max_tokens": 300
  }' \
  http://localhost:30080/v1/completions

# eventually, you should be able to see more replicas of the model
sleep 20 && kubectl get hpa -A
