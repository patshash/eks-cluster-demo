# EKS Cluster Demo

Deploys an Amazon EKS cluster in `ap-southeast-2` (Sydney) using Terraform, with HashiCorp Vault installed via Helm.

## Architecture

- **VPC** with 3 public and 3 private subnets across 3 AZs
- **EKS** cluster (Kubernetes 1.31) with managed node group
- **Worker nodes**: t3.medium instances (min 1, max 3, desired 2) in private subnets
- **NAT Gateway** for outbound internet access from private subnets
- **HashiCorp Vault** deployed in HA mode with Raft integrated storage and the Agent Injector enabled

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0

## Usage

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the cluster and Vault
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name eks-cluster-demo
```

## Vault Initialization

After the cluster is deployed, Vault must be initialized:

```bash
# Initialize Vault on the first pod (only needed once)
kubectl exec -n vault vault-0 -- vault operator init

# Unseal vault-0 using the unseal keys from the init output
kubectl exec -n vault vault-0 -- vault operator unseal <unseal-key>

# Join vault-1 and vault-2 to the Raft cluster, then unseal them
kubectl exec -n vault vault-1 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n vault vault-1 -- vault operator unseal <unseal-key>

kubectl exec -n vault vault-2 -- vault operator raft join http://vault-0.vault-internal:8200
kubectl exec -n vault vault-2 -- vault operator unseal <unseal-key>
```

## Cleanup

```bash
terraform destroy
```

## Inputs

| Variable | Description | Default |
|----------|-------------|---------|
| `region` | AWS region | `ap-southeast-2` |
| `cluster_name` | EKS cluster name | `eks-cluster-demo` |
| `cluster_version` | Kubernetes version | `1.31` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `instance_type` | Node instance type | `t3.medium` |
| `node_min_size` | Min nodes | `1` |
| `node_max_size` | Max nodes | `3` |
| `node_desired_size` | Desired nodes | `2` |
| `vault_namespace` | Kubernetes namespace for Vault | `vault` |
| `vault_replicas` | Number of Vault HA replicas | `3` |
| `vault_chart_version` | Vault Helm chart version | `0.29.1` |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Cluster API endpoint |
| `configure_kubectl` | Command to configure kubectl |
| `vault_namespace` | Kubernetes namespace where Vault is deployed |
| `vault_address` | Command to get the Vault service address |
