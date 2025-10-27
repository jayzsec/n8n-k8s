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
# Added --namespace n8n-staging
helm install postgres bitnami/postgresql --set auth.postgresPassword=postgres --set auth.database=n8n --namespace n8n-staging

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
echo "--- 🔐 Generating a new TLS certificate and creating the 'tls-secret'... ---"
cat > req.conf <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
CN = n8n.example.com
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = n8n.example.com
EOF

# ... (openssl commands) ...
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -config req.conf

# IMPORTANT: When you create the secret, specify the namespace!
echo "--- 🔐 Generating TLS certificate for staging namespace... ---"
kubectl create secret tls tls-secret --key tls.key --cert tls.crt \
  --namespace n8n-staging \
  --dry-run=client -o yaml | kubectl apply -f -

# Create or replace the Kubernetes secret
# kubectl create secret tls tls-secret --key tls.key --cert tls.crt --dry-run=client -o yaml | kubectl apply -f -

# Clean up temporary files
echo "--- 🧹 Cleaning up temporary certificate files... ---"
rm req.conf tls.key tls.crt

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
