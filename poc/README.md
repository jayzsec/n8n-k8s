# n8n Local Deployment with Kubernetes and Podman

This project deploys a self-hosted instance of n8n on a local Kubernetes cluster managed by Podman. It uses Helm to install PostgreSQL for the database and an NGINX Ingress Controller for external access.

## 📋 Prerequisites

Before you begin, ensure you have the following tools installed and configured on your system:
* **Podman**: For running containers and managing the local Kubernetes environment.
* **kubectl**: The Kubernetes command-line tool.
* **Helm**: The package manager for Kubernetes.
* **Ansible**: For configuring the or localhost. (Optional)
## 📁 Project Files

* `setup.sh`: The main automated setup script. It installs dependencies, generates a TLS certificate, and deploys all resources.
* `n8n-deployment.yaml`: Defines the Kubernetes Deployment for the n8n application.
* `n8n-service.yaml`: Creates a `ClusterIP` service to expose the n8n deployment internally.
* `n8n-ingress.yaml`: Configures the NGINX Ingress rule to route external traffic from `n8n.example.com` to the n8n service.
* `setup.yml`: The playbook to be used if using ansible. (functions the same as setup.sh) 

## 🚀 Setup Instructions

### Step 1: Run the Setup Script
Make the main script executable and run it. This will install all dependencies, create the TLS secret, and apply the Kubernetes configurations.

```bash
chmod +x setup.sh
./setup.sh
```

Step 2: Configure Hostname Resolution

You must map the hostname n8n.example.com to your local machine. This allows your browser to find the service running via the port-forward.

Open your hosts file with root permissions:
```bash
    sudo nano /etc/hosts
    # Add the following line to the end of the file:
    127.0.0.1   n8n.example.com
    # Save and close the file.
```

Step 3: Start the Port-Forward

Open a new, separate terminal window and run the following command. This command creates a bridge from your local machine's port 8443 to the Ingress Controller's port 443.

Leave this terminal running.
```bash
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8443:443
```

🌐 Accessing n8n

You can now access your n8n instance in a web browser at:

https://n8n.example.com:8443

You will see a browser privacy warning. This is expected because the setup script generated a self-signed TLS certificate. Click "Advanced" and then "Proceed to n8n.example.com (unsafe)" to continue.
