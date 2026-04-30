#!/bin/bash
set -e

kubectl config use-context personal
docker build --no-cache -f Dockerfile -t ghcr.io/niro58/inspect:latest .
docker push ghcr.io/niro58/inspect:latest
kubectl apply -f .k8s/prod/pvc.yaml
kubectl apply -f .k8s/prod/service.yaml
kubectl apply -f .k8s/prod/deployment.yaml
kubectl rollout restart deployment/inspect -n personal
kubectl rollout status deployment/inspect -n personal
