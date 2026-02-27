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
                kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s

                exit;;
            * )
                echo "Invalid response"
        esac

    done

else

    kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s

fi

# Kubectl Executions

## Redis Server
kubectl apply -f ./k8s/redis/namespace.yaml
kubectl apply -f ./k8s/redis/configmap.yaml
kubectl apply -f ./k8s/redis/deployment.yaml
kubectl apply -f ./k8s/redis/service.yaml


## KEDA


## Job Orchestrator


## Browseless Deployment
