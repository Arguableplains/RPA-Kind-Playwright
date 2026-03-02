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

# Kubectl Executions

## Java WorkLoader
kubectl apply -f ./k8s/JavaWorkLoader/namespace.yaml
kubectl apply -f ./k8s/JavaWorkLoader/configmap.yaml
kubectl apply -f ./k8s/JavaWorkLoader/PV.yaml
kubectl apply -f ./k8s/JavaWorkLoader/PVC.yaml

## Redis Server
echo "Redis Server Config"
kubectl apply -f ./k8s/redis/namespace.yaml
kubectl apply -f ./k8s/redis/configmap.yaml
kubectl apply -f ./k8s/redis/deployment.yaml
kubectl apply -f ./k8s/redis/service.yaml

## KEDA
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.10.1/keda-2.10.1.yaml
kubectl wait --for=condition=ready pod -l app=keda-operator -n keda --timeout=60s
kubectl apply -f ./k8s/KEDA/keda-trigger-auth.yaml
kubectl apply -f ./k8s/KEDA/keda-scaled-job.yaml

## Job Orchestrator
kubectl apply -f ./k8s/JobOrchestrator/namespace.yaml
kubectl apply -f ./k8s/JobOrchestrator/PV.yaml
kubectl apply -f ./k8s/JobOrchestrator/PVC.yaml

## Browseless Deployment
kubectl apply -f ./k8s/Browserless/namespace.yaml
kubectl apply -f ./k8s/Browserless/secret.yaml
kubectl apply -f ./k8s/Browserless/deployment.yaml
kubectl apply -f ./k8s/Browserless/service.yaml