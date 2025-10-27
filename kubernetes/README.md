# n8n Kubernetes Deployment for Staging

This project deploys a scalable, self-hosted n8n instance onto a local Kubernetes cluster (such as one provided by Podman) configured for a staging environment.

It uses **Kustomize** to manage environment-specific configurations, **Helm** to deploy dependencies (PostgreSQL, NGINX), and a private GitHub Container Registry (`ghcr.io`) to host the n8n application image.

## Architecture

This setup provisions the following components:

  * **n8n Deployment**: The main n8n application, configured to run in "queue" mode.
  * **PostgreSQL Database**: Deployed via the Bitnami Helm chart, used as the persistent database for n8n workflows and data.
  * **Redis**: Deployed as a simple pod and service, used for n8n's queue management.
  * **NGINX Ingress Controller**: Deployed via Helm, this acts as the reverse proxy, handling SSL termination and routing traffic from a hostname (`n8n.example.com`) to the internal `n8n` service.

## 📋 Prerequisites

Before you begin, ensure you have the following tools installed on your system (e.g., Fedora):

  * **Podman**: For running containers and managing the local Kubernetes environment.
  * **`kubectl`**: The Kubernetes command-line tool.
  * **`helm`**: The package manager for Kubernetes.

## 🚀 Setup Instructions

Follow these steps to build the private container image and deploy the full stack to your `n8n-staging` namespace.

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
    This downloads the official n8n image and re-uploads it to your private registry.

    ```bash
    # 1. Pull an official version
    podman pull n8nio/n8n:latest

    # 2. Tag it for your registry
    podman tag n8nio/n8n:latest ghcr.io/jayzsec/n8n:1.2.0-staging

    # 3. Push it to your private registry
    podman push ghcr.io/jayzsec/n8n:1.2.0-staging
    ```

### Step 2: One-Time Kubernetes Setup

1.  **Create the Staging Namespace**:

    ```bash
    kubectl apply -f kubernetes/overlays/staging/namespace.yaml
    ```

2.  **Create the Image Pull Secret**:
    This command tells Kubernetes how to log in to `ghcr.io` to pull your private image.

    ```bash
    kubectl create secret docker-registry ghcr-creds \
      --docker-server=ghcr.io \
      --docker-username=jayzsec \
      --docker-password=YOUR_GITHUB_PAT_HERE \
      --namespace=n8n-staging
    ```

### Step 3: Run the Deployment Script

This script installs all Helm charts and applies all your Kustomize configurations for the `n8n-staging` environment.

```bash
chmod +x kubernetes/reset_and_deploy.sh
./kubernetes/reset_and_deploy.sh
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

You will see a browser privacy warning (e.g., "Your connection is not private"). This is **expected and normal** because the setup script generated a *self-signed* TLS certificate.

Click **"Advanced"** and then **"Proceed to n8n.example.com (unsafe)"** to continue.

-----

## 🐛 Troubleshooting Guide

A quick reference for the issues faced during this setup.

  * **Error:** `404 Not Found`

      * **Cause:** The NGINX Ingress Controller is working, but the `Ingress` resource (the "rule" to connect `n8n.example.com` to your service) was not created or applied.
      * **Fix:** Create and apply the `n8n-ingress.yaml` file.

  * **Error:** `CreateContainerConfigError` with message `secret "postgres-postgresql" not found`

      * **Cause:** The `n8n` pod (in the `n8n-staging` namespace) could not find the database secret. This is because Helm installed PostgreSQL in the `default` namespace.
      * **Fix:** Modify the `helm install postgres ...` command in `reset_and_deploy.sh` to include the `--namespace n8n-staging` flag.

  * **Error:** `error: no matching resources found` during `kubectl wait ...`

      * **Cause:** The `kubectl wait` command was looking for the PostgreSQL pod in the `default` namespace, but Helm correctly installed it in `n8n-staging`.
      * **Fix:** Modify the `kubectl wait ...` command in `reset_and_deploy.sh` to include the `--namespace n8n-staging` flag.

  * **Error:** `503 Service Temporarily Unavailable`

      * **Cause:** NGINX is working, but the `n8n` pod is unhealthy and failing its health checks. This was traced to the application crashing on startup.
      * **Log Message:** `RangeError: options.port should be >= 0 and < 65536. Received type number (NaN).`
      * **Root Cause:** A Kubernetes feature auto-injects an environment variable for the `n8n` service called `N8N_PORT`. The `n8n` app reads this variable, but its value is a URL (`tcp://...`) and not a port number, causing a crash.
      * **Fix:** Explicitly set the port in `kubernetes/base/n8n-deployment.yaml` to override the bad value:
        ```yaml
        env:
        - name: N8N_PORT
          value: "5678"
        # ... other env vars ...
        ```