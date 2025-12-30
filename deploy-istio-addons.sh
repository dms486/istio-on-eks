#!/bin/bash

# Deploy the addons first
for ADDON in prometheus kiali 
do
    ADDON_URL="https://raw.githubusercontent.com/istio/istio/refs/tags/1.28.1/samples/addons/$ADDON.yaml"
    kubectl apply -f $ADDON_URL
done

# Wait for deployments to be created
echo "Waiting for deployments to be created..."
sleep 10

# Patch each deployment with nodeSelector and tolerations
DEPLOYMENTS=(
    "prometheus"
    "kiali"
)

for DEPLOYMENT in "${DEPLOYMENTS[@]}"
do
    echo "Patching deployment: $DEPLOYMENT"
    
    # Check if deployment exists
    if kubectl get deployment $DEPLOYMENT -n istio-system >/dev/null 2>&1; then
        # Patch with nodeSelector and tolerations
        kubectl patch deployment $DEPLOYMENT -n istio-system --type='merge' -p='{
            "spec": {
                "template": {
                    "spec": {
                        "nodeSelector": {
                            "karpenter.sh/nodepool": "system"
                        },
                        "tolerations": [
                            {
                                "key": "CriticalAddonsOnly",
                                "operator": "Exists",
                                "effect": "NoSchedule"
                            }
                        ]
                    }
                }
            }
        }'
        echo "✓ Patched $DEPLOYMENT"
    else
        echo "⚠ Deployment $DEPLOYMENT not found, skipping..."
    fi
done

# Wait for all pods to be ready
echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=Ready --timeout=240s pods --all -n istio-system

echo "✓ All addons patched and ready!"