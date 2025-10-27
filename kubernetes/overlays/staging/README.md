#


```commandline
kubernetes/
├── base/
│   ├── n8n-deployment.yaml
│   ├── n8n-service.yml
│   ├── redis-deployment.yaml
│   ├── redis-service.yaml
│   ├── logging-deployment.yaml
│   ├── logging-service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml      # New Kustomize file
└── overlays/
    └── staging/
        ├── namespace.yaml        # New: Creates the staging namespace
        ├── resource-quota.yaml   # New: Sets resource limits
        ├── deployment-patch.yaml # New: Modifies the deployment for staging
        └── kustomization.yaml    # New Kustomize file for staging
```
