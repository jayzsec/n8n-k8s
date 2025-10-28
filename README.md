# n8n Kubernetes Deployment

This repository contains configurations for deploying a self-hosted n8n instance on Kubernetes.

The primary, recommended solution uses **Kustomize, Helm, and cert-manager** for a robust, environment-aware deployment.

An older, alternative "Proof of Concept" (PoC) is also included, which uses **Ansible and manual shell scripts**.

## Main Deployment (Recommended)

This is the main, modern solution for deploying n8n. It uses Kustomize to manage `base` and `staging` environments, Helm for dependencies, and `cert-manager` for automated TLS.

* **Technology:** Kustomize, Helm, `cert-manager`, GitHub Container Registry
* **Location:** [`./kubernetes/`](./kubernetes/)
* **Instructions:** See the detailed guide in the directory: **[kubernetes/README.md](./kubernetes/README.md)**

## Proof of Concept (Alternative)

This directory contains an older, alternative setup. It uses Ansible or a more complex shell script to achieve a similar result, but lacks the flexibility of the Kustomize build.

* **Technology:** Ansible, Helm, OpenSSL (manual)
* **Location:** [`./poc/`](./poc/)
* **Instructions:** See the guide in that directory: **[poc/README.md](./poc/README.md)**