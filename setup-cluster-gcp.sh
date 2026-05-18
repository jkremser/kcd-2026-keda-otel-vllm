#!/bin/bash
set -xe
source .env-gcp

# Delete the cluster if it already exists
gcloud beta container --project "$GCP_PROJECT" clusters delete "$CLUSTER_NAME" --zone "$ZONE"

# Create the GKE cluster
gcloud beta container --project "$GCP_PROJECT" clusters create "$CLUSTER_NAME" \
  --zone "$ZONE" \
  --tier "standard" \
  --no-enable-basic-auth \
  --cluster-version "$CLUSTER_VERSION" \
  --release-channel "regular" \
  --machine-type "n2d-standard-8" \
  --image-type "COS_CONTAINERD" \
  --disk-type "pd-balanced" \
  --disk-size "100" \
  --metadata disable-legacy-endpoints=true \
  --scopes \
    "https://www.googleapis.com/auth/devstorage.read_only,\
https://www.googleapis.com/auth/logging.write,\
https://www.googleapis.com/auth/monitoring,\
https://www.googleapis.com/auth/servicecontrol,\
https://www.googleapis.com/auth/service.management.readonly,\
https://www.googleapis.com/auth/trace.append" \
  --max-pods-per-node "110" \
  --num-nodes "1" \
  --logging=SYSTEM,WORKLOAD \
  --monitoring=SYSTEM,STORAGE,POD,DEPLOYMENT,STATEFULSET,DAEMONSET,HPA,CADVISOR,KUBELET \
  --enable-ip-alias \
  --network "projects/$GCP_PROJECT/global/networks/default" \
  --subnetwork "projects/$GCP_PROJECT/regions/us-central1/subnetworks/default" \
  --no-enable-intra-node-visibility \
  --default-max-pods-per-node "110" \
  --enable-ip-access \
  --security-posture=standard \
  --workload-vulnerability-scanning=disabled \
  --no-enable-master-authorized-networks \
  --no-enable-google-cloud-access \
  --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
  --enable-autoupgrade \
  --enable-autorepair \
  --max-surge-upgrade 1 \
  --max-unavailable-upgrade 0 \
  --binauthz-evaluation-mode=DISABLED \
  --enable-managed-prometheus \
  --enable-shielded-nodes \
  --enable-autoprovisioning \
  --min-cpu 0 \
  --min-memory 0 \
  --max-cpu 1000 \
  --max-memory 40960 \
  --autoprovisioning-scopes=https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/devstorage.read_only \
  --min-accelerator=type="$ACCELERATOR_TYPE",count=0 \
  --max-accelerator=type="$ACCELERATOR_TYPE",count=4 \
  --node-locations "$ZONE"

# now continue w/ https://github.com/kedify/otel-add-on/blob/main/examples/vllm/setup.sh
