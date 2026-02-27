# Deployment Status

## ✅ Deployment Complete (Vault Initialized & Unsealed)

### Phase 1: Infrastructure (AWS Resources)
- **Status**: ✅ Complete
- **Cluster Name**: eks-cluster-demo
- **Region**: ap-southeast-2
- **Endpoint**: https://1B0E3B5C1FDB0F6C8D51A00327C08ADA.gr7.ap-southeast-2.eks.amazonaws.com
- **Nodes**: 2x t3.medium (Ready)
- **Kubernetes Version**: 1.31.14-eks-70ce843
- **VPC ID**: vpc-0f9197dd8fbfe61d5

### Phase 2: Applications (Vault + VSO)
- **Status**: ✅ Complete & Operational
- **Vault Version**: 1.15.2
- **Vault Mode**: Standalone (file storage - ephemeral)
- **Vault Status**: ✅ Initialized, Unsealed, Running
- **Vault Agent Injector**: Running
- **VSO Version**: 0.7.1
- **VSO Controller**: Running & Ready

### Vault Credentials
⚠️ **Root token and unseal key stored securely in your deployment environment**
See `vault-deployment/terraform.tfvars` for credential management

### Namespaces Created
- `vault` - Vault server and agent injector
- `vault-secrets-operator` - VSO controller
- `vso-demo` - Demo namespace with service account

## State Files

Each phase maintains independent Terraform state:
- **Phase 1**: `infrastructure/terraform.tfstate`
- **Phase 2**: `vault-deployment/terraform.tfstate`

## Quick Commands

```bash
# Check cluster status
kubectl cluster-info

# Check Vault pods (should show Running & Ready)
kubectl get pods -n vault
kubectl get statefulset -n vault

# Check Vault status
kubectl exec vault-0 -n vault -- vault status

# Check VSO
kubectl get deploy -n vault-secrets-operator

# Access Vault (from your machine)
kubectl port-forward -n vault svc/vault 8200:8200
# Then: curl http://localhost:8200/v1/sys/health

# Login to Vault CLI
vault login <your-root-token>  # Use token from secure storage
```

## Troubleshooting

### Pod Scheduling Issues (Fixed)
**Problem**: `pod vault-0 does not have a host assigned`  
**Cause**: PersistentVolumeClaims without storage class bound  
**Solution**: Disabled persistent storage and used ephemeral file storage instead

### EBS CSI Driver Not Installed
The cluster doesn't have the EBS CSI driver, so PVCs cannot be provisioned to EBS volumes. For production use, install the EBS CSI add-on:
```bash
aws eks create-addon --cluster-name eks-cluster-demo --addon-name aws-ebs-csi-driver
```

## Notes

- Vault is running in **standalone mode** (single instance, file storage)
- Data is ephemeral and will be lost if the pod is deleted
- For production, use persistent storage with EBS CSI driver and HA mode
- Both phases were deployed with doormat for AWS authentication
- Infrastructure and applications are separated for better resilience
- Each phase can be managed independently
