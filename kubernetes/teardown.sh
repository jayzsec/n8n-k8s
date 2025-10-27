#!/bin/bash

# All helm managed package
helm uninstall postgres --namespace n8n-staging
helm uninstall ingress-nginx --namespace ingress-nginx

# Delete namespace
kubectl delete -f ./overlays/staging/namespace.yaml
kubectl delete namespace ingress-nginx
