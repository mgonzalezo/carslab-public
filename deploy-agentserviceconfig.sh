#!/bin/bash
#
# Deploy AgentServiceConfig for Assisted Installer
# This ensures the correct storage class (lso-filesystemclass) is always used
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_FILE="${SCRIPT_DIR}/agentserviceconfig.yaml"

echo "====================================================="
echo "Deploying AgentServiceConfig for Assisted Installer"
echo "====================================================="
echo ""

# Check if the YAML file exists
if [ ! -f "$YAML_FILE" ]; then
    echo "ERROR: agentserviceconfig.yaml not found at $YAML_FILE"
    exit 1
fi

# Verify storage class exists
echo "Checking if lso-filesystemclass storage class exists..."
if ! oc get storageclass lso-filesystemclass &>/dev/null; then
    echo "ERROR: Storage class 'lso-filesystemclass' not found!"
    echo ""
    echo "Available storage classes:"
    oc get storageclass
    exit 1
fi
echo "✓ Storage class lso-filesystemclass found"
echo ""

# Check if AgentServiceConfig already exists
if oc get agentserviceconfig agent -n multicluster-engine &>/dev/null; then
    echo "WARNING: AgentServiceConfig 'agent' already exists"
    read -p "Do you want to delete and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing AgentServiceConfig..."
        oc delete agentserviceconfig agent -n multicluster-engine
        echo "Waiting 10 seconds for cleanup..."
        sleep 10

        # Clean up any remaining PVCs
        if oc get pvc -n multicluster-engine | grep -q assisted; then
            echo "Cleaning up existing PVCs..."
            oc delete pvc -n multicluster-engine --selector=app=assisted-service --ignore-not-found=true
            oc delete pvc -n multicluster-engine image-service-data-assisted-image-service-0 --ignore-not-found=true
            sleep 5
        fi
    else
        echo "Skipping deployment"
        exit 0
    fi
fi

# Apply the AgentServiceConfig
echo "Applying AgentServiceConfig from $YAML_FILE..."
oc apply -f "$YAML_FILE"
echo ""

# Wait for deployment
echo "Waiting for AgentServiceConfig to become healthy (timeout: 10 minutes)..."
if oc wait --for=condition=DeploymentsHealthy agentserviceconfig/agent -n multicluster-engine --timeout=600s; then
    echo ""
    echo "✓ AgentServiceConfig deployed successfully!"
    echo ""

    # Show status
    echo "Current status:"
    echo "---------------"
    oc get pods -n multicluster-engine | grep assisted
    echo ""
    oc get pvc -n multicluster-engine
    echo ""
    echo "====================================================="
    echo "AgentServiceConfig is ready for cluster deployments!"
    echo "====================================================="
else
    echo ""
    echo "ERROR: AgentServiceConfig failed to become healthy"
    echo ""
    echo "Pod status:"
    oc get pods -n multicluster-engine | grep assisted
    echo ""
    echo "Check logs with:"
    echo "  oc logs -n multicluster-engine -l app=assisted-service"
    exit 1
fi
