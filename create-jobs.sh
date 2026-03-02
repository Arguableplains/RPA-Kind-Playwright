#!/bin/bash

NAMESPACE="java-work-loader"
JOB_FILE="k8s/JavaWorkLoader/job.yaml"

if [ $# -eq 0 ]; then
    echo "Usage: $0 <number_of_jobs> [job_yaml_file]"
    echo "Example: $0 5"
    echo "Example: $0 3 custom-job.yaml"
    exit 1
fi

NUM_JOBS=$1
YAML_FILE=${2:-$JOB_FILE}

echo "Creating $NUM_JOBS jobs in namespace $NAMESPACE..."

for i in $(seq 1 $NUM_JOBS); do
    JOB_NAME=$(kubectl create -f "$YAML_FILE" -n "$NAMESPACE" 2>&1 | grep -oP 'job\.batch/\K[a-z0-9-]+')
    echo "Created job: $JOB_NAME"
done

echo "Done! Jobs in namespace:"
kubectl get jobs -n "$NAMESPACE" --no-headers
