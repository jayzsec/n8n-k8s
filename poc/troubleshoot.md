This file summarizes the issues you faced and their solutions, serving as a quick reference for future debugging.

```markdown
# Troubleshooting Guide

This document outlines the common issues encountered during the setup and how to resolve them.

## 🚨 Problem 1: `400 Bad Request`

* **Symptom**: After running the setup, accessing `http://localhost:8443` results in a `400 Bad Request` error from NGINX.
* **Cause**: This error occurs for two reasons:
    1.  **Incorrect Hostname**: The Ingress Controller is configured to only respond to requests for the hostname `n8n.example.com`, not `localhost`.
    2.  **Incorrect Protocol**: The ingress is set up for secure `https` traffic, but the request was made using plain `http`.
* **Solution**:
    1.  **Map Hostname**: Edit your `/etc/hosts` file to point `n8n.example.com` to your local machine by adding the line: `127.0.0.1 n8n.example.com`.
    2.  **Use Correct URL**: Always use the full, correct URL in your browser: `https://n8n.example.com:8443`.

---

## 🚨 Problem 2: `404 Not Found`

* **Symptom**: After fixing the `400 Bad Request` error, accessing `https://n8n.example.com:8443` now shows a `404 Not Found` page from NGINX. The browser's TLS warning indicates the Ingress Controller is being reached, but it cannot find where to send the traffic.
* **Cause**: The Kubernetes **`Ingress`** resource is missing or was not applied. Without this resource, the NGINX Ingress Controller has no rules to connect the external hostname to the internal `n8n` service.
* **Diagnosis**:
    1.  Verify that all resources are running with `kubectl get deployment,pod,service,ingress`. The output for `ingress` will be empty.
    2.  Confirm the Ingress resource is missing by running `kubectl describe ingress n8n-ingress`, which will return an error: `ingresses.networking.k8s.io "n8n-ingress" not found`.
* **Solution**:
    1.  Ensure a file named `n8n-ingress.yaml` exists with the correct configuration to route traffic from `n8n.example.com` to the `n8n` service on port `5678`.
    2.  Apply the configuration to the cluster using the command:
        ```bash
        kubectl apply -f n8n-ingress.yaml
        ```
    3.  Wait about 30 seconds for the Ingress Controller to update its rules, then try accessing the URL again.

