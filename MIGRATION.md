# Migration Guide: Monolithic to Refactored Terraform

This guide explains the refactoring that separates infrastructure and application deployment into two distinct Terraform configurations.

## What Changed

### Directory Structure

**Before:**
```
eks-cluster-demo/
├── eks.tf
├── vpc.tf
├── vault.tf
├── vault_secrets_operator_demo.tf
├── variables.tf
├── outputs.tf
├── versions.tf
└── terraform.tfvars
```

**After:**
```
eks-cluster-demo/
├── infrastructure/              # Phase 1: AWS Infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   └── terraform.tfstate        # Separate state
├── vault-deployment/            # Phase 2: Vault Applications
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── versions.tf
│   ├── terraform.tfvars.example
│   └── terraform.tfstate        # Separate state
├── deploy.sh                     # Automated deployment script
├── REFACTORED_README.md
└── MIGRATION.md                  # This file
```

## Why This Refactoring?

### Problem with Monolithic Approach
1. **Coupling**: Application state mixed with infrastructure state
2. **Resilience**: Node group failures blocked entire deployment
3. **Flexibility**: Couldn't update applications without re-planning infrastructure
4. **Reusability**: Infrastructure couldn't be shared with other applications
5. **Troubleshooting**: Difficult to isolate and fix issues
6. **Iteration**: Long terraform plans when changing small application configs

### Benefits of Refactored Approach
1. ✅ **Separation of Concerns**: Infrastructure and applications are independent
2. ✅ **Resilience**: Can retry failed deployments without affecting stable infrastructure
3. ✅ **Flexibility**: Vault configuration can be updated independently
4. ✅ **Reusability**: Infrastructure can be used for other workloads
5. ✅ **Troubleshooting**: Issues isolated to specific phase
6. ✅ **Performance**: Smaller terraform plans with faster execution

## File Mapping

### Infrastructure Phase

| Old File | New Location | Content |
|----------|--------------|---------|
| `vpc.tf` | `infrastructure/main.tf` | VPC module |
| `eks.tf` | `infrastructure/main.tf` | EKS module |
| Part of `variables.tf` | `infrastructure/variables.tf` | Infrastructure vars |
| Part of `outputs.tf` | `infrastructure/outputs.tf` | Infrastructure outputs |
| `versions.tf` | `infrastructure/versions.tf` | AWS provider config |

**New Infrastructure Outputs:**
- `vpc_id`
- `private_subnets`
- (Existing: `cluster_name`, `cluster_endpoint`, etc.)

### Vault Deployment Phase

| Old File | New Location | Content |
|----------|--------------|---------|
| `vault.tf` | `vault-deployment/main.tf` | Vault Helm charts |
| `vault_secrets_operator_demo.tf` | `vault-deployment/main.tf` | VSO and demo resources |
| Part of `variables.tf` | `vault-deployment/variables.tf` | Vault vars |
| Part of `outputs.tf` | `vault-deployment/outputs.tf` | Vault outputs |
| `versions.tf` | `vault-deployment/versions.tf` | K8s/Helm provider config |

**New Data Sources:**
- `data.aws_eks_cluster`: References infrastructure cluster
- `data.aws_eks_cluster_auth`: Gets cluster credentials

## Key Architectural Changes

### 1. Provider Configuration

**Before** (single `versions.tf`):
```hcl
provider "aws" { ... }
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = ...
}
provider "helm" { ... }
```

**After:**
- **Infrastructure** (`infrastructure/versions.tf`): Only AWS provider
- **Vault** (`vault-deployment/versions.tf`): AWS + Kubernetes + Helm providers
  - Uses data source to reference existing cluster
  - No dependency on infrastructure module

### 2. Data Flow

```
Infrastructure Phase 1:
┌─────────────────────────────────┐
│ VPC, EKS, Node Groups, IAM      │
│ Outputs: cluster_name, endpoint │
│ State: infrastructure/tfstate    │
└─────────────────────────────────┘
                 ↓
         (outputs saved or passed)
                 ↓
┌─────────────────────────────────┐
│ Vault Deployment Phase 2        │
│ Reads: cluster_name via var     │
│ Uses: data.aws_eks_cluster      │
│ Deploys: Vault + VSO            │
│ State: vault-deployment/tfstate │
└─────────────────────────────────┘
```

### 3. Variable Flow

**Phase 1 Input (`infrastructure/terraform.tfvars`):**
```hcl
cluster_name    = "eks-cluster-demo"
node_desired_size = 2
...
```

**Phase 1 Output (`infrastructure/terraform.output`):**
```
cluster_name = "eks-cluster-demo"
cluster_endpoint = "https://..."
configure_kubectl = "aws eks update-kubeconfig ..."
```

**Phase 2 Input (`vault-deployment/terraform.tfvars`):**
```hcl
cluster_name = "eks-cluster-demo"  # From Phase 1 output
vault_replicas = 3
...
```

## Migration Steps (if you have existing state)

### Option A: Start Fresh (Recommended)

```bash
# 1. Destroy current resources
cd eks-cluster-demo
terraform destroy -auto-approve

# 2. Move to new structure
rm -rf .terraform terraform.tfstate* *.plan

# 3. Deploy infrastructure
cd infrastructure
terraform init
terraform apply

# 4. Deploy vault
cd ../vault-deployment
terraform init
terraform apply
```

### Option B: Migrate Existing State

```bash
# 1. Export current state
cd eks-cluster-demo
terraform show > current_state.json

# 2. Destroy current configuration
terraform destroy -auto-approve

# 3. Initialize new structure
cd infrastructure
terraform init
terraform apply

# Note: You'll need to manually restore Vault state if critical
```

### Option C: Keep Running While Migrating

```bash
# 1. Deploy new infrastructure in parallel
cd infrastructure
terraform init
terraform apply  # Creates new cluster

# 2. Migrate workloads to new cluster

# 3. Destroy old infrastructure
cd ../old_location
terraform destroy

# This is only practical if you have multiple clusters
```

## Deployment Using New Structure

### Quick Deploy (All in One)
```bash
./deploy.sh full
```

### Phased Deployment
```bash
# Phase 1: Infrastructure
./deploy.sh infra

# Phase 2: Vault
./deploy.sh vault

# Verify
./deploy.sh verify

# Or manual deployment
cd infrastructure && terraform apply
cd ../vault-deployment && terraform apply
```

### Destroy
```bash
./deploy.sh destroy

# Or manual
cd vault-deployment && terraform destroy
cd ../infrastructure && terraform destroy
```

## State File Management

### Infrastructure State
- **File**: `infrastructure/terraform.tfstate`
- **Size**: ~100-200 KB
- **Sensitivity**: High (contains encryption keys, certificates)
- **Backup**: Recommended - contains sensitive infrastructure details

### Vault Deployment State
- **File**: `vault-deployment/terraform.tfstate`
- **Size**: ~50-100 KB
- **Sensitivity**: Medium (contains Helm release info)
- **Backup**: Recommended - contains deployment configuration

### Remote State (Recommended for Production)

```hcl
# infrastructure/main.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "eks-infrastructure/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# vault-deployment/main.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "vault-deployment/terraform.tfstate"
    region         = "ap-southeast-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Environment Isolation

The new structure allows easy environment isolation:

```
eks-cluster-demo/
├── infrastructure/
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
└── vault-deployment/
    ├── dev/
    │   └── terraform.tfvars
    ├── staging/
    │   └── terraform.tfvars
    └── prod/
        └── terraform.tfvars
```

Deploy to environment:
```bash
cd infrastructure/dev
terraform apply -var-file=terraform.tfvars
```

## Troubleshooting Migration Issues

### State Lost
If Terraform state was lost:
```bash
# Infrastructure
cd infrastructure
terraform import module.vpc.aws_vpc.this <vpc-id>
terraform import module.eks.aws_eks_cluster.this[0] <cluster-name>

# Vault (requires working cluster)
cd ../vault-deployment
kubectl describe ns vault | grep -i uid  # Get namespace UID
# Manually recreate resources or restore from backup
```

### Provider Mismatch
If Kubernetes provider can't authenticate:
```bash
# Verify cluster exists
aws eks describe-cluster --name <cluster-name>

# Reconfigure kubectl
aws eks update-kubeconfig --name <cluster-name>

# Test connection
kubectl cluster-info
```

### Module Dependencies
If you see "module not found" errors:
```bash
cd infrastructure
terraform init  # Download modules

cd ../vault-deployment
terraform init  # Download modules
```

## Comparison: Command Reference

| Task | Before | After |
|------|--------|-------|
| Init all | `terraform init` | `cd infrastructure && terraform init` + `cd ../vault-deployment && terraform init` |
| Plan all | `terraform plan` | `./deploy.sh verify` (plans both) |
| Apply all | `terraform apply` | `./deploy.sh full` |
| Destroy all | `terraform destroy` (with workarounds) | `./deploy.sh destroy` |
| Update app | `terraform apply` (re-plans infra) | `cd vault-deployment && terraform apply` |
| Update infra | `terraform apply` (redeploys apps) | `cd infrastructure && terraform apply` |

## Best Practices After Migration

1. **Use Remote State**: Store state files in S3 with encryption and locking
2. **Automate Deployments**: Use CI/CD pipeline with the `deploy.sh` script
3. **Separate AWS Accounts**: Dev/staging/prod in different accounts
4. **Workspace Isolation**: Use Terraform workspaces for environment variation
5. **State Backups**: Regular backups of terraform.tfstate files
6. **Access Control**: Limit who can run terraform apply/destroy
7. **Change Approval**: Require approval for production changes
8. **Documentation**: Keep terraform.tfvars.example updated

## FAQ

**Q: Do I need to destroy and recreate everything?**
A: Not necessarily, but it's the safest approach. You can migrate state, but it's complex.

**Q: Can I still use a single command to deploy everything?**
A: Yes, use `./deploy.sh full` which handles both phases.

**Q: What if node group creation fails again?**
A: Much easier to debug now. Infrastructure is stable, just retry Phase 2. Or destroy Phase 2, fix infrastructure, and reapply.

**Q: How do I scale the Vault deployment independently?**
A: `cd vault-deployment && terraform apply -var vault_replicas=5`

**Q: Can I use this with multiple clusters?**
A: Yes! Create separate directories like `infrastructure-prod/`, `infrastructure-dev/`, etc.

## Next Steps

1. Review the refactored code in `infrastructure/` and `vault-deployment/`
2. Update `terraform.tfvars` files with your values
3. Run `./deploy.sh full` to deploy to a clean AWS account
4. Refer to `REFACTORED_README.md` for detailed documentation
