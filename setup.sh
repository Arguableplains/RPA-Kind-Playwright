#!/bin/bash

set -euo pipefail

############################################
# Helpers
############################################

log_info()    { echo -e "\033[1;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[1;32m[SUCCESS]\033[0m $1"; }
log_warn()    { echo -e "\033[1;33m[WARNING]\033[0m $1"; }
log_error()   { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

step() {
  echo
  echo "=============================================="
  echo "🚀 $1"
  echo "=============================================="
}

############################################
# PRE-FLIGHT CHECKS
############################################

step "RUNNING PRE-FLIGHT CHECKS"

require_command() {
  if ! command -v "$1" &>/dev/null; then
    log_error "Required command '$1' not found."
    exit 1
  else
    log_success "'$1' found."
  fi
}

log_info "Checking required CLI tools..."

require_command docker
require_command kubectl
require_command kind
require_command grep
require_command awk

log_info "Checking Docker daemon..."

if ! docker info &>/dev/null; then
  log_error "Docker daemon is not running."
  echo "Start Docker and try again."
  exit 1
fi

log_success "Docker is running."

log_info "Checking Docker buildx..."

if ! docker buildx version &>/dev/null; then
  log_error "Docker buildx is not available."
  echo "Install buildx or enable it in Docker."
  exit 1
fi

log_success "Docker buildx available."

log_info "Checking internet connectivity..."

if ! curl -s https://github.com &>/dev/null; then
  log_warn "Could not verify internet connectivity. KEDA install may fail."
else
  log_success "Internet connectivity OK."
fi

############################################
# Variables
############################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIND_CLUSTER_NAME="rpa-poc-cluster"
ROBOTS_DIR="./k8s/JobOrchestrator/robots"

cd "$SCRIPT_DIR"

############################################
# KIND SETUP
############################################

step "KIND CLUSTER SETUP"

if kind get clusters 2>/dev/null | grep -q "$KIND_CLUSTER_NAME"; then
    log_warn "Cluster '$KIND_CLUSTER_NAME' already exists."

    while true; do
        read -p "Ignore cluster recreation? [Y/n] " yn
        case $yn in 
            yes | Y | y | "" )
                log_info "Using existing cluster."
                break;;
            no | N | n )
                log_info "Deleting existing cluster..."
                kind delete cluster --name "$KIND_CLUSTER_NAME"

                log_info "Creating new cluster..."
                kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s --config ./k8s/KIND/kind-config.yaml
                log_success "Cluster recreated successfully."
                break;;
            * )
                log_error "Invalid response. Please type Y or N."
        esac
    done
else
    log_info "Creating cluster '$KIND_CLUSTER_NAME'..."
    kind create cluster --name "$KIND_CLUSTER_NAME" --wait 60s --config ./k8s/KIND/kind-config.yaml
    log_success "Cluster created successfully."
fi

############################################
# DOCKER IMAGES
############################################

step "DOCKER IMAGE BUILD & LOAD"

while true; do
    read -p "Build Docker images? [y/N] " yn

    case $yn in 
        no | N | n | "" )
            log_info "Skipping Docker build."
            break;;
        yes | Y | y )
            log_info "Building and loading Docker images..."

            ########################################
            # Java Redis Publisher
            ########################################
            log_info "Building Redis Publisher..."
            docker buildx build -t rpa_kind_playwright/redis-task-publisher:1.0 ./java/
            kind load docker-image rpa_kind_playwright/redis-task-publisher:1.0 --name "$KIND_CLUSTER_NAME"
            log_success "Redis Publisher ready."

            ########################################
            # Job Orchestrator
            ########################################
            log_info "Building Job Orchestrator..."
            docker buildx build -t rpa_kind_playwright/job-orchestrator:1.0 ./k8s/JobOrchestrator/docker/
            kind load docker-image rpa_kind_playwright/job-orchestrator:1.0 --name "$KIND_CLUSTER_NAME"
            log_success "Job Orchestrator ready."

            ########################################
            # Robots
            ########################################
            log_info "Building Robot Images..."

            for dir in "$ROBOTS_DIR"/*/; do
                [ -d "$dir" ] || continue

                FOLDER_NAME=$(basename "$dir")
                IMAGE_ROBOT_NAME="${FOLDER_NAME//_/-}"
                IMAGE_NAME="rpa_kind_playwright/${IMAGE_ROBOT_NAME}:1.0"

                log_info "Building $IMAGE_NAME..."
                docker buildx build --quiet -t "$IMAGE_NAME" "$dir"

                log_info "Loading $IMAGE_NAME into cluster..."
                kind load docker-image "$IMAGE_NAME" --name "$KIND_CLUSTER_NAME"

                log_success "Robot '$FOLDER_NAME' ready."
            done

            log_success "All Docker images built and loaded."
            break;;
        * )
            log_error "Invalid response. Please type Y or N."
    esac
done

############################################
# KUBERNETES DEPLOYMENTS
############################################

step "APPLYING KUBERNETES RESOURCES"

############################################
# Java WorkLoader
############################################
log_info "Deploying Java WorkLoader namespace..."
kubectl apply -f ./k8s/JavaWorkLoader/namespace.yaml

############################################
# Redis
############################################
log_info "Deploying Redis..."
kubectl apply -f ./k8s/redis/namespace.yaml
kubectl apply -f ./k8s/redis/configmap.yaml
kubectl apply -f ./k8s/redis/deployment.yaml
kubectl apply -f ./k8s/redis/service.yaml
log_success "Redis deployed."

############################################
# KEDA
############################################
log_info "Deploying KEDA..."
kubectl apply -f ./k8s/KEDA/namespace.yaml
kubectl apply -f https://github.com/kedacore/keda/releases/download/v2.10.1/keda-2.10.1.yaml
kubectl wait --for=condition=ready pod -l app=keda-operator -n keda --timeout=120s
kubectl apply -f ./k8s/KEDA/keda-trigger-auth.yaml
kubectl apply -f ./k8s/KEDA/keda-scaled-job.yaml
log_success "KEDA deployed and ready."

############################################
# Browserless
############################################
log_info "Deploying Browserless..."
kubectl apply -f ./k8s/Browserless/namespace.yaml
kubectl apply -f ./k8s/Browserless/secret.yaml
kubectl apply -f ./k8s/Browserless/deployment.yaml
kubectl wait --for=condition=ready pod -l app=browserless -n browserless --timeout=180s
kubectl apply -f ./k8s/Browserless/service.yaml
log_success "Browserless deployed."

############################################
# Job Orchestrator + Robots
############################################
log_info "Deploying Job Orchestrator & Robots..."
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-namespace.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-output-pv.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/robots-output-pvc.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/browserless-token-secret.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/job-creator-role.yaml
kubectl apply -f ./k8s/JobOrchestrator/robots/job-creator-rolebinding.yaml
log_success "Robots infrastructure deployed."

############################################
# Final Status
############################################

step "CLUSTER STATUS"

kubectl get pods --all-namespaces
log_success "Setup completed successfully."