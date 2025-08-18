#!/bin/bash
NAMESPACE="${1:-ssp}"
kubectl get deployments.apps \
  --namespace "${NAMESPACE}" \
  --selector 'app.kubernetes.io/instance=ssp' \
  --show-kind \
  --output 'name' \
| xargs -l kubectl rollout restart \
  --namespace "${NAMESPACE}"
