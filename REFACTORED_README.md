# EKS Cluster with Vault Deployment - Refactored Structure

This repository contains a refactored Terraform configuration that separates AWS infrastructure provisioning from Vault application deployment into two distinct phases.

## Architecture

### Phase 1: Infrastructure (`infrastructure/`)
Provisions the base AWS infrastructure:
- VPC with public/private subnets across 3 availability zones
- NAT gateway for private subnet egress
- EKS cluster (1.31)
- Managed node group (2 t3.medium instances by default)
- Security groups and IAM roles

**Prerequisites:**
- AWS credentials (via doormat)
- Terraform >= 1.0
- AWS provider >= 5.0

**Deployment:**
```bash
cd infrastructure
terraform init
terraform plan
terraform apply
```

**Outputs:**
- `cluster_name`: EKS cluster name
- `cluster_endpoint`: EKS API endpoint
- `cluster_certificate_authority_data`: Cluster CA certificate
- `configure_kubectl`: Command to configure kubectl
- `vpc_id`: VPC ID
- `private_subnets`: Private subnet IDs

### Phase 2: Vault Deployment (`vault-deployment/`)
Deploys Vault and Vault Secrets Operator (VSO) on the provisioned EKS cluster:
- Vault Helm chart with HA mode and Raft storage
- Vault Secrets Operator with default connection configuration
- Demo namespace with service account for testing VSO

**Prerequisites:**
- Phase 1 infrastructure deployed
- EKS cluster running and accessible
- `kubectl` configured to access the cluster
- Terraform AWS, Kubernetes, and Helm providers

**Deployment:**
```bash
cd vault-deployment

# Create terraform.tfvars with infrastructure outputs
cat > terraform.tfvars <<EOF
region       = "ap-southeast-2"
cluster_name = "<cluster_name_from_phase1>"
EOF

terraform init
terraform plan
terraform apply
```

**Inputs:**
- `cluster_name`: EKS cluster name (from Phase 1 outputs)
- `region`: AWS region
- `vault_namespace`: Namespace for Vault (default: "vault")
- `vault_chart_version`: Vault Helm chart version (default: "0.27.0")
- `vault_replicas`: Number of Vault replicas (default: 3)
- `vso_namespace`: Namespace for VSO (default: "vault-secrets-operator")
- `vso_chart_version`: VSO Helm chart version (default: "0.7.1")

**Outputs:**
- `vault_namespace`: Namespace where Vault is deployed
- `vault_address`: Command to get Vault service address
- `vso_namespace`: Namespace where VSO is deployed
- `vso_demo_namespace`: Demo namespace for VSO testing

## Workflow

### Step 1: Deploy Infrastructure
```bash
cd infrastructure
terraform init
terraform apply
```

Save the outputs (especially `cluster_name` and `configure_kubectl`).

### Step 2: Configure kubectl
```bash
aws eks update-kubeconfig --region ap-southeast-2 --name <cluster_name>
kubectl get nodes  # Verify cluster access
```

### Step 3: Deploy Vault Applications
```bash
cd ../vault-deployment
terraform init

# Create terraform.tfvars
echo 'cluster_name = "<cluster_name_from_step1>"' > terraform.tfvars
echo 'region = "ap-southeast-2"' >> terraform.tfvars

terraform apply
```

### Step 4: Verify Vault Deployment
```bash
kubectl get pods -n vault
kubectl get pods -n vault-secrets-operator
kubectl get pods -n vso-demo
```

## Key Differences from Monolithic Approach

### Before (Monolithic)
- All resources (infrastructure + applications) in single terraform run
- Node group creation failures blocked entire deployment
- Application state mixed with infrastructure state
- Difficult to iterate on applications independently
- Destroying infrastructure required workarounds for kubernetes resources

### After (Separated Phases)
✅ **Infrastructure Independence**
- Infrastructure provisioned and stable
- Can retry/update independently of applications
- Easier to troubleshoot infrastructure issues

✅ **Application Flexibility**
- Deploy/update Vault without touching infrastructure
- Easy to modify Vault configuration
- Can use infrastructure as a data source

✅ **Better State Management**
- Separate tfstate files for infrastructure and applications
- Easier to recover from failures
- Clear separation of concerns

✅ **Reusability**
- Infrastructure module can be reused for other applications
- Vault deployment can reference multiple clusters

## Destroying Resources

### Option 1: Destroy in reverse order (recommended)
```bash
# Destroy applications first
cd vault-deployment
terraform destroy

# Then destroy infrastructure
cd ../infrastructure
terraform destroy
```

### Option 2: Destroy infrastructure (cascades to K8s resources)
```bash
cd infrastructure
terraform destroy
```

## Terraform State Management

### Infrastructure State
- Location: `infrastructure/terraform.tfstate`
- Contains: VPC, EKS cluster, node groups, IAM roles
- Sensitive: Yes (contains encryption keys, certificates)

### Vault Deployment State
- Location: `vault-deployment/terraform.tfstate`
- Contains: Kubernetes namespaces, Helm releases
- Depends on: Infrastructure state (reads via data source)

## Configuration Files

### Infrastructure Variables (`infrastructure/terraform.tfvars`)
```hcl
region                = "ap-southeast-2"
cluster_name         = "eks-cluster-demo"
cluster_version      = "1.31"
vpc_cidr             = "10.0.0.0/16"
instance_type        = "t3.medium"
node_min_size        = 1
node_max_size        = 3
node_desired_size    = 2
```

### Vault Deployment Variables (`vault-deployment/terraform.tfvars`)
```hcl
region              = "ap-southeast-2"
cluster_name        = "eks-cluster-demo"
vault_namespace     = "vault"
vault_chart_version = "0.27.0"
vault_replicas      = 3
vso_namespace       = "vault-secrets-operator"
vso_chart_version   = "0.7.1"
```

## Requirements

- Terraform >= 1.0
- AWS CLI configured with credentials (or doormat)
- kubectl >= 1.20
- Helm >= 3.0

## AWS Providers Used

- `terraform-aws-modules/vpc/aws`: VPC infrastructure
- `terraform-aws-modules/eks/aws`: EKS cluster and node groups
- `hashicorp/kubernetes`: Kubernetes resources
- `hashicorp/helm`: Helm chart deployments
- `hashicorp/aws`: ECS cluster data lookups

## Troubleshooting

### Node Group Creation Failures
If nodes fail to join the cluster:
1. Check security group rules allow kubelet communication
2. Verify subnet routing (NAT gateway working)
3. Check node instance logs in EC2 console
4. Delete failed node group and retry infrastructure apply

### Vault Pod Startup Issues
- Check PVC creation: `kubectl get pvc -n vault`
- Check logs: `kubectl logs -n vault deployment/vault`
- Ensure Helm repository is accessible

### Kubectl Connection Issues
- Verify cluster credentials: `aws eks describe-cluster --name <cluster_name>`
- Reconfigure kubeconfig: `aws eks update-kubeconfig --name <cluster_name>`
- Check security groups allow API access

## Next Steps

After successful deployment:
1. Initialize Vault: See Vault documentation for initialization steps
2. Configure Kubernetes auth method in Vault
3. Create demo secrets in Vault KV store
4. Uncomment VSO demo resources in `vault-deployment/main.tf`
5. Test Vault Secrets Operator with demo application
