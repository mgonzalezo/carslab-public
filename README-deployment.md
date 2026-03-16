# Deployment Guide - AgentServiceConfig

## Quick Start

### Deploy AgentServiceConfig (Automated)

```bash
./deploy-agentserviceconfig.sh
```

This script will:
- ✅ Verify storage class exists
- ✅ Apply from the versioned YAML file
- ✅ Wait for healthy deployment
- ✅ Show final status

### Deploy AgentServiceConfig (Manual)

```bash
oc apply -f agentserviceconfig.yaml
oc wait --for=condition=DeploymentsHealthy agentserviceconfig/agent -n multicluster-engine --timeout=600s
oc get pods -n multicluster-engine | grep assisted
```

---

## Storage Configuration

**Current Setup:**
- **Storage Class:** `lso-filesystemclass` (Local Storage Operator)
- **Storage Backend:** Local disks on supervisor nodes

**Storage Requirements:**
- Database: 10Gi
- Filesystem: 20Gi
- Images: 50Gi
- **Total:** ~80Gi

---

## Verification Commands

### Check AgentServiceConfig Status
```bash
oc get agentserviceconfig agent -n multicluster-engine
```

### Check Pods
```bash
oc get pods -n multicluster-engine | grep assisted
```

Expected output:
```
assisted-service-xxxxx-xxxxx      2/2   Running
assisted-image-service-0          1/1   Running
```

### Check PVCs
```bash
oc get pvc -n multicluster-engine
```

All PVCs should be **Bound** with `lso-filesystemclass` storage class.

### Check Logs
```bash
# Assisted Service logs
oc logs -n multicluster-engine -l app=assisted-service -c assisted-service -f

# Image Service logs
oc logs -n multicluster-engine assisted-image-service-0 -f
```

---

## Common Issues

### Issue: PVCs stuck in Pending

**Cause:** Storage class doesn't exist or no available storage

**Solution:**
1. Check available storage classes:
   ```bash
   oc get storageclass
   ```

2. Verify Local Storage Operator is configured:
   ```bash
   oc get localvolume -n openshift-local-storage
   ```

3. Update agentserviceconfig.yaml if needed to use the correct storage class

### Issue: ImagePullBackOff

**Cause:** Temporary image registry issues (usually resolves automatically)

**Solution:** Wait 1-2 minutes - the pod will retry and succeed

---

## Storage Class Reference

Your cluster uses **Local Storage Operator (LSO)** with these characteristics:

- **Name:** `lso-filesystemclass`
- **Provisioner:** `kubernetes.io/no-provisioner`
- **Binding Mode:** `WaitForFirstConsumer`
- **Backend:** Local volumes from `/dev/autopart/lv_*` on supervisor nodes

**Note:** LVMS (`lvms-vg1`) is NOT installed on this cluster. Always use `lso-filesystemclass`.

---

## Next Steps After Deployment

Once AgentServiceConfig is healthy:

1. Create InfraEnv for your cluster
2. Create ClusterInstance (or SiteConfig)
3. Deploy SNO clusters using Assisted Installer

Example for fiesta.cars2.lab:
```bash
cd rhocp-clusters/fiesta.cars2.lab/
oc apply -k .
```
