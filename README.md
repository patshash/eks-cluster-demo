# EKS Cluster Demo

Deploys an Amazon EKS cluster in `ap-southeast-2` (Sydney) using Terraform.

## Architecture

- **VPC** with 3 public and 3 private subnets across 3 AZs
- **EKS** cluster (Kubernetes 1.31) with managed node group
- **Worker nodes**: t3.medium instances (min 1, max 3, desired 2) in private subnets
- **NAT Gateway** for outbound internet access from private subnets

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.3
- [AWS CLI](https://aws.amazon.com/cli/) configured with credentials
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## Usage

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the cluster
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region ap-southeast-2 --name eks-cluster-demo
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

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Cluster API endpoint |
| `configure_kubectl` | Command to configure kubectl |
