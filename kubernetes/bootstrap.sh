#!/bin/bash

# Apply namespace for the ghcr credentials
kubectl apply -f ./overlays/staging/namespace.yaml

# Run the ghcr command
./ghcr-creds.sh

# finally run the deploy command
./reset_and_deploy.sh
