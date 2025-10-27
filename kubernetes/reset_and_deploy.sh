#!/bin/bash

# A script to completely reset and redeploy the n8n application stack.
# Assumes you have a running Kubernetes cluster context.

# Stop on any error
set -e

echo "--- 🚀 Starting the n8n deployment script ---"

# 1. Add the required Helm repositories
echo "--- 📦 Adding the Bitnami and Ingress-Nginx Helm repositories... ---"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Install PostgreSQL using Helm
echo "--- 🐘 Installing PostgreSQL via Helm... ---"
# Use the -f flag to provide secrets from the ignored values file
helm install postgres bitnami/postgresql \
  -f helm-values.yaml \
  --set auth.database=n8n \
  --namespace n8n-staging

# 3. Install the NGINX Ingress Controller using Helm
echo "--- 🌐 Installing NGINX Ingress Controller via Helm... ---"
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

# 4. Wait for dependencies to become ready
echo "--- ⏳ Waiting for PostgreSQL to become ready... ---"
# Added --namespace n8n-staging
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s --namespace n8n-staging

echo "--- ⏳ Waiting for NGINX Ingress Controller to become ready... ---"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# 5. Apply all your Kubernetes configurations using Kustomize for staging
echo "--- 📄 Applying Kubernetes configuration for the 'staging' environment... ---"
kubectl apply -k overlays/staging

# 6. Generate the TLS certificate and create the secret
echo "--- 🔐 Letting cert-manager create the 'tls-secret'... ---"
# All the old openssl and kubectl create secret commands are removed.
# Kustomize has already applied the 'Certificate' resource.
# We just need to wait for the secret to be ready.

kubectl wait --for=condition=ready certificate/n8n-tls \
  --namespace n8n-staging \
  --timeout=120s

echo "--- ✅ TLS Secret is ready! ---"

# Clean up temporary files
#echo "--- 🧹 Cleaning up temporary certificate files... ---"
#rm req.conf tls.key tls.crt

echo ""
echo "--- 🎉 All done! ---"
echo ""
echo "The n8n stack has been deployed. Monitor pod status with:"
echo "kubectl get pods -w"
echo ""
echo "Once running, set up port-forwarding in a new terminal:"
echo "kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443"
echo ""
echo "Then access n8n at: https://n8n.example.com:8443"
echo ""
