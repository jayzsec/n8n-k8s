#!/bin/bash

# This script is designed to be re-runnable by tearing down resources first.
# It is NOT idempotent. It is destructive and less safe than the Ansible version.

set -e

# --- 💣 DESTRUCTION PHASE ---
# We ignore errors (|| true) in case the resources don't exist on the first run.

echo "--- 💣 Tearing down existing Helm releases to ensure a clean slate... ---"
helm uninstall postgres &>/dev/null || true
helm uninstall ingress-nginx --namespace ingress-nginx &>/dev/null || true

echo "--- 💣 Deleting existing secrets and namespaces... ---"
kubectl delete secret tls-secret --namespace default &>/dev/null || true
# Wait a moment for the namespace to be fully terminated if it exists
if kubectl get namespace ingress-nginx &>/dev/null; then
    echo "--- ⏳ Waiting for 'ingress-nginx' namespace to terminate... ---"
    kubectl delete namespace ingress-nginx --wait=true &>/dev/null || true
fi


# --- 🚀 CREATION PHASE ---

# 1. Add the required Helm repositories
echo "--- 📦 Adding the Bitnami and Ingress-Nginx Helm repositories... ---"
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# 2. Install PostgreSQL using Helm
echo "--- 🐘 Installing PostgreSQL via Helm... ---"
helm install postgres bitnami/postgresql --set auth.postgresPassword=postgres --set auth.database=n8n

# 3. Install the NGINX Ingress Controller using Helm
echo "--- 🌐 Installing NGINX Ingress Controller via Helm... ---"
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace

echo "--- ⏳ Waiting for PostgreSQL to become ready... ---"
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql --timeout=300s

echo "--- ⏳ Waiting for NGINX Ingress Controller to become ready... ---"
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# 4. Apply all your Kubernetes configurations from the local directory
echo "--- 📄 Applying all local Kubernetes YAML files... ---"
# Use --overwrite to force apply changes
kubectl apply --overwrite=true -f ./k8s_manifests/

if [ -d "monitoring-stack" ]; then
    echo "--- 📄 Applying monitoring-stack YAML files... ---"
    kubectl apply --overwrite=true -f monitoring-stack/
else
    echo "--- ⚠ Warning: 'monitoring-stack' directory not found. Skipping. ---"
fi

# 5. Generate the TLS certificate with SAN and create the secret
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

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -config req.conf

kubectl create secret tls tls-secret --key tls.key --cert tls.crt

echo "--- 🧹 Cleaning up temporary certificate files... ---"
rm req.conf tls.key tls.crt

echo ""
echo "--- 🎉 All done! Setup is complete. ---"
echo ""
echo "The final step is to create a network bridge to the Ingress Controller."
echo "Open a NEW, SEPARATE terminal window and run the following command."
echo "We are using port 8443 because ports below 1024 require admin permissions."
echo ""
echo "kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443"
echo ""
echo "Then, in another terminal or your browser, you can finally access n8n at:"
echo "https://n8n.example.com:8443"
echo ""
