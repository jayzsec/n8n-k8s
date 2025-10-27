# n8n Kubernetes Deployment for Staging

This project deploys a scalable, self-hosted n8n instance onto a local Kubernetes cluster (such as one provided by Podman) configured for a staging environment.

It uses **Kustomize** to manage environment-specific configurations, **Helm** to deploy dependencies, **`cert-manager`** for automated TLS, and a private GitHub Container Registry (`ghcr.io`) for the application image.

## Architecture

This setup provisions the following components:

  * **n8n Deployment**: The main n8n application, configured to run in "queue" mode.
  * **PostgreSQL Database**: Deployed via the Bitnami Helm chart. Secrets are managed securely via a git-ignored `helm-values.yaml` file.
  * **Redis**: Deployed as a `StatefulSet` to provide a stable network identity and persistent storage, making it resilient to restarts.
  * **NGINX Ingress Controller**: Deployed via Helm, this acts as the reverse proxy.
  * **`cert-manager`**: Automatically provisions a self-signed TLS certificate and creates the `tls-secret` required by the Ingress.
  * **Kustomize Overlays**: Manages the configuration differences between the `base` setup and the `staging` environment, including resource quotas and image tags.

## 📋 Prerequisites

Before you begin, ensure you have the following tools installed on your system (e.g., Fedora):

  * **Podman**: For running containers and managing the local Kubernetes environment.
  * **`kubectl`**: The Kubernetes command-line tool.
  * **`helm`**: The package manager for Kubernetes.

## 🚀 Setup Instructions

Follow these steps to build the private container image and deploy the full stack.

### Step 1: Build and Push Your Private n8n Image

1.  **Get a GitHub Personal Access Token (PAT)**:

      * Go to your GitHub Settings \> **Developer settings** \> **Personal access tokens** \> **Tokens (classic)**.
      * Click **"Generate new token"** and select **`write:packages`** scope.
      * Copy this token. You will use it as a password.

2.  **Log in to GitHub Container Registry (`ghcr.io`)**:

    ```bash
    # Username: your-github-username (e.g., jayzsec)
    # Password: Your new GitHub PAT
    podman login ghcr.io
    ```

3.  **Pull, Tag, and Push the n8n Image**:

    ```bash
    # 1. Pull an official version
    podman pull n8nio/n8n:latest

    # 2. Tag it for your registry
    podman tag n8nio/n8n:latest ghcr.io/jayzsec/n8n:1.112.2-staging

    # 3. Push it to your private registry
    podman push ghcr.io/jayzsec/n8n:1.112.2-staging
    ```

### Step 2: One-Time Cluster Setup

1.  **Install `cert-manager`**:
    This only needs to be done once per cluster. It will manage all your TLS certificates.

    ```bash
    helm repo add jetstack https://charts.jetstack.io
    helm repo update
    helm install cert-manager jetstack/cert-manager \
      --namespace cert-manager \
      --create-namespace \
      --set installCRDs=true
    ```

2.  **Create Helm Secrets File**:
    This file holds your database password and is ignored by Git.

    ```bash
    # Create the .gitignore file to protect your secrets
    echo "helm-values.yaml" > kubernetes/.gitignore

    # Create the values file with your secure password
    cat > kubernetes/helm-values.yaml <<EOF
    auth:
      postgresPassword: "YourSecurePasswordGoesHere"
    EOF
    ```

    *(Remember to replace the password with a strong one)*

### Step 3: Run the Bootstrap Script

This is the main script to deploy or redeploy your application. It handles creating the namespace, the image pull secret, and running the main deployment script.

1.  **Make scripts executable**:

    ```bash
    chmod +x kubernetes/bootstrap.sh
    chmod +x kubernetes/ghcr-creds.sh
    chmod +x kubernetes/reset_and_deploy.sh
    ```

2.  **Run the bootstrap script**:
    This script will securely prompt you for your GitHub PAT.

    ```bash
    ./kubernetes/bootstrap.sh
    ```

### Step 4: Configure Hostname Resolution

You must map the hostname `n8n.example.com` to your local machine.

1.  Open your hosts file with root permissions:
    ```bash
    sudo nano /etc/hosts
    ```
2.  Add this line to the end of the file:
    ```
    127.0.0.1   n8n.example.com
    ```

### Step 5: Start the Port-Forward

Open a **new, separate terminal** and run this command. It creates a secure bridge from your local port `8443` to the Ingress Controller inside the cluster.

**Leave this terminal running.**

```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443
```

-----

## 🌐 Accessing n8n

You can now access your n8n instance in a web browser at:

**[https://n8n.example.com:8443](https://n8n.example.com:8443)**

You will see a browser privacy warning (e.g., "Your connection is not private"). This is **expected and normal** because `cert-manager` generated a *self-signed* certificate for local development.

Click **"Advanced"** and then **"Proceed to n8n.example.com (unsafe)"** to continue.

-----

## 🔁 Redeploying with an Updated Image

If you push a new version of your image (e.g., `ghcr.io/jayzsec/n8n:1.112.3-staging`):

1.  Update the `image:` tag in `kubernetes/overlays/staging/deployment-patch.yaml`.
2.  Force a rolling restart to pick up the change. The `imagePullPolicy: Always` will ensure the new image is pulled.
    ```bash
    kubectl rollout restart deployment n8n -n n8n-staging
    ```

-----

## 🐛 Troubleshooting Guide

  * **Error:** `ImagePullBackOff` or Pod stuck in `ContainerCreating`.

      * **Cause:** The `ghcr-creds` secret is missing, expired, or incorrect. Kubernetes cannot pull your private image.
      * **Fix:** Re-run the credential script: `./kubernetes/ghcr-creds.sh`. It will securely prompt you for a valid GitHub PAT and recreate the secret.

  * **Error:** `503 Service Temporarily Unavailable`

      * **Cause:** NGINX is working, but the `n8n` pod is unhealthy. This was traced to the application crashing on startup.
      * **Log Message:** `RangeError: options.port should be >= 0 and < 65536. Received type number (NaN).`
      * **Root Cause:** A Kubernetes feature auto-injects an env var for the `n8n` service called `N8N_PORT`. The `n8n` app reads this, but its value is a URL (`tcp://...`) and not a port, causing a crash.
      * **Fix:** We fixed this by renaming the service in `kubernetes/base/n8n-svc.yml` to **`n8n-svc`**. This prevents the name collision, which is the clean, long-term solution. The Ingress was updated to point to `n8n-svc`.

  * **Error:** `CreateContainerConfigError` with message `secret "postgres-postgresql" not found`

      * **Cause:** The `n8n` pod (in `n8n-staging`) could not find the database secret. This is because Helm installed PostgreSQL in the `default` namespace.
      * **Fix:** The `helm install postgres ...` command in `reset_and_deploy.sh` was updated with the `--namespace n8n-staging` flag.

  * **Error:** Ingress is missing a certificate (`tls-secret` not found).

      * **Cause:** `cert-manager` may have failed to create the certificate.
      * **Fix:** Check the certificate status: `kubectl describe certificate n8n-tls -n n8n-staging`. If there is an error, check the `cert-manager` pod logs: `kubectl logs -n cert-manager deploy/cert-manager`.