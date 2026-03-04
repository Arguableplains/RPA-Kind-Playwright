#!/bin/bash

# Variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CLUSTER_NAME="rpa-poc-cluster"

cd "$SCRIPT_DIR"

# Kind Setup

## Kind Verification and Restart confirmation if needed
if kind get clusters 2>/dev/null | grep -q "$KIND_CLUSTER_NAME"; then

    echo "There is already an RPA_POC_CLUSTER..."

    while true; do

        read -p "Ignore the kind cluster setup? [Y/n] " yn

        case $yn in 
            yes | Y | y | "" )
                echo "Ok, we will proceed with the setup"
                break;;
            no | No | n )
                echo "Ok, a kind restart will be done."

                echo "Deleting Kind existing Cluster."
                kind delete cluster --name "$KIND_CLUSTER_NAME"

                echo "Creating new Kind Cluster."
                kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s --config ./k8s/KIND/kind-config.yaml

                break;;
            * )
                echo "Invalid response"
        esac

    done

else

    kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s --config ./k8s/KIND/kind-config.yaml

fi

# Docker Images Config

while true; do

    read -p "Build this project Docker Images? [y/N] " yn

    case $yn in 
            no | N | n | "" )
                echo "Ok, we will proceed with the setup"
                break;;
            yes | Y | y )
                echo "Ok, docker images will be built and loaded into the cluster."

                echo "Java Redis Publisher"
                docker build -t rpa_kind_playwright/redis-task-publisher:1.0 ./java/
                kind load docker-image rpa_kind_playwright/redis-task-publisher:1.0 --name "$KIND_CLUSTER_NAME"

                echo "Job Orchestrator"
                docker build -t rpa_kind_playwright/job-orchestrator:1.0 ./k8s/JobOrchestrator/docker/
                kind load docker-image rpa_kind_playwright/job-orchestrator:1.0 --name "$KIND_CLUSTER_NAME"

                echo ROBOT IMAGES

                ROBOTS_DIR="./k8s/JobOrchestrator/robots"

                for dir in "$ROBOTS_DIR"/*/; do
                    [ -d "$dir" ] || continue

                    FOLDER_NAME=$(basename "$dir")

                    # Replace underscores with hyphens for Docker image name
                    IMAGE_ROBOT_NAME="${FOLDER_NAME//_/-}"

                    IMAGE_NAME="rpa_kind_playwright/${IMAGE_ROBOT_NAME}:1.0"

                    echo "Building $IMAGE_NAME from $dir"
                    docker build --quiet -t "$IMAGE_NAME" "$dir" || exit 1

                    echo "Loading $IMAGE_NAME into kind cluster $KIND_CLUSTER_NAME"
                    kind load docker-image "$IMAGE_NAME" --name "$KIND_CLUSTER_NAME" || exit 1

                    echo "Finished $FOLDER_NAME"
                    echo "-----------------------------"
                done

                break;;
            * )
                echo "Invalid response"
    esac

done

# Kubectl Executions

## Java WorkLoader
kubectl apply -f ./k8s/JavaWorkLoader/namespace.yaml

## Redis Server
kubectl apply -f ./k8s/redis/namespace.yaml
kubectl apply -f ./k8s/redis/configmap.yaml
kubectl apply -f ./k8s/redis/deployment.yaml
kubectl apply -f ./k8s/redis/service.yaml

## KEDA
kubectl apply -f ./k8s/KEDA/namespace.yaml
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.10.1/keda-2.10.1.yaml
kubectl wait --for=condition=ready pod -l app=keda-operator -n keda --timeout=60s
kubectl apply -f ./k8s/KEDA/keda-trigger-auth.yaml
kubectl apply -f ./k8s/KEDA/keda-scaled-job.yaml

## Browseless Deployment
kubectl apply -f ./k8s/Browserless/namespace.yaml
kubectl apply -f ./k8s/Browserless/secret.yaml
kubectl apply -f ./k8s/Browserless/deployment.yaml
kubectl apply -f ./k8s/Browserless/service.yaml

# Job Orchestrator and Robots
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-namespace.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-output-pv.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-output-pvc.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/browserless-token-secret.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/job-creator-role.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/job-creator-rolebinding.yaml