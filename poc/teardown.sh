#!/bin/bash

# 1. Delete the local YAML manifests (from k8s_manifests and monitoring-stack)
kubectl delete --filename ./k8s_manifests/ --namespace default
kubectl delete --filename ./monitoring-stack/ --namespace default

# 2. Delete the TLS secret
kubectl delete secret tls-secret --namespace default

# 3. Uninstall the Helm releases
helm uninstall postgres --namespace default
helm uninstall ingress-nginx --namespace ingress-nginx

# 4. Delete the ingress namespace
kubectl delete namespace ingress-nginx

# 5. (Optional) Clean up local temp files
rm -f /tmp/tls.key /tmp/tls.csr /tmp/tls.crt
