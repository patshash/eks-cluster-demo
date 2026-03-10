# EKS Cluster Demo — Terraform Stacks

Deploys an Amazon EKS cluster in `ap-southeast-2` (Sydney) using **Terraform Stacks**, with HashiCorp Vault and the Vault Secrets Operator (VSO) installed via Helm.

## Architecture

- **VPC** with 3 public and 3 private subnets across 3 AZs
- **EKS** cluster (Kubernetes 1.31) with managed node group
- **Worker nodes**: t3.medium instances (min 1, max 3, desired 2) in private subnets
- **NAT Gateway** for outbound internet access from private subnets
- **HashiCorp Vault** deployed in HA mode with Raft integrated storage and the Agent Injector enabled
- **Vault Secrets Operator (VSO)** deployed to sync Vault secrets natively into Kubernetes Secrets
- **VSO demo** in the `vso-demo` namespace with a service account for VaultAuth integration

## Stack Structure

```
├── tfstack.hcl              # Stack orchestration — providers, components, wiring
├── tfdeploy.hcl             # Deployment configurations (dev, prod)
└── components/
    ├── networking/           # VPC, subnets, NAT gateway
    ├── eks/                  # EKS cluster, managed node group, cluster auth
    └── vault/                # Vault (Helm), VSO (Helm), demo namespace
```

### Component Dependency Graph

```
networking ──► eks ──► vault
   (VPC)      (cluster)  (kubernetes/helm workloads)
```

The Stacks runtime automatically resolves ordering: `networking` deploys first, its VPC/subnet outputs feed into `eks`, and the `kubernetes`/`helm` providers for `vault` depend on the EKS cluster endpoint and auth token.

## Prerequisites

- [HCP Terraform](https://app.terraform.io/) organization with **Stacks** enabled
- An AWS IAM role configured for [OIDC-based authentication](https://developer.hashicorp.com/terraform/cloud-docs/workspaces/dynamic-provider-credentials/aws-configuration) with your HCP Terraform organization
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (for post-deploy verification)

## Usage

### 1. Configure Deployments

Edit `tfdeploy.hcl` and replace the `<REPLACE_WITH_AWS_ROLE_ARN>` placeholders with your IAM role ARN(s).

### 2. Create a Stack in HCP Terraform

1. Navigate to your HCP Terraform organization
2. Create a new **Stack** linked to this repository
3. HCP Terraform will detect `tfstack.hcl` and `tfdeploy.hcl` automatically

### 3. Deploy

HCP Terraform will plan and apply the stack deployments. Each deployment (`development`, `production`) is orchestrated independently with its own set of inputs.

### 4. Configure kubectl

After deployment, configure kubectl for your environment:

```bash
# Development
aws eks update-kubeconfig --region ap-southeast-2 --name eks-cluster-demo-dev

# Production
aws eks update-kubeconfig --region ap-southeast-2 --name eks-cluster-demo-prod
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

## Vault Secrets Operator Demo

The VSO demo (`vso-demo` namespace) is provisioned by Terraform and demonstrates end-to-end secret synchronisation from Vault into a native Kubernetes Secret.

### How It Works

| Resource | Kind | Purpose |
|---|---|---|
| `default` | `VaultConnection` | Points VSO at the in-cluster Vault address |
| `demo-auth` | `VaultAuth` | Authenticates to Vault via the Kubernetes auth method using the `demo-sa` service account |
| `demo-secret` | `VaultStaticSecret` | Syncs `secret/demo/config` (KV v2) into a Kubernetes Secret called `demo-secret`, refreshing every 30 s |
| `vso-demo` | `Deployment` | Busybox pod that prints the synced secret values from environment variables |

### Required Vault-side Configuration

After Vault is initialized and unsealed, run the following commands once:

```bash
# Log in to Vault with the root token (or another admin token)
kubectl exec -n vault vault-0 -- vault login <root-token>

# Enable the KV v2 secrets engine
kubectl exec -n vault vault-0 -- vault secrets enable -path=secret kv-v2

# Write a demo secret
kubectl exec -n vault vault-0 -- vault kv put secret/demo/config username="demo-user" password="s3cr3t"

# Enable the Kubernetes auth method
kubectl exec -n vault vault-0 -- vault auth enable kubernetes

# Configure the Kubernetes auth method (retrieve the service-account JWT and CA from the cluster)
KUBE_HOST=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN_REVIEWER_JWT=$(kubectl create token vault -n vault --duration=8760h)
KUBE_CA_CERT=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d)
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/config \
  kubernetes_host="$KUBE_HOST" \
  token_reviewer_jwt="$TOKEN_REVIEWER_JWT" \
  kubernetes_ca_cert="$KUBE_CA_CERT"

# Create a policy that allows reading the demo secret
kubectl exec -n vault vault-0 -- vault policy write demo-policy - <<EOF
path "secret/data/demo/config" {
  capabilities = ["read"]
}
EOF

# Create the Kubernetes auth role referenced by the VaultAuth CRD
kubectl exec -n vault vault-0 -- vault write auth/kubernetes/role/demo-role \
  bound_service_account_names=demo-sa \
  bound_service_account_namespaces=vso-demo \
  policies=demo-policy \
  ttl=1h
```

### Verifying the Demo

```bash
# Check that VSO has synced the secret (view key names and decoded values individually)
kubectl get secret demo-secret -n vso-demo -o yaml

# Decode a specific key, e.g. username
kubectl get secret demo-secret -n vso-demo -o jsonpath='{.data.username}' | base64 -d

# Tail the demo pod logs to see the synced secret key names printed every 30 s
kubectl logs -n vso-demo -l app=vso-demo -f
```

## Cleanup

To destroy resources, trigger a destroy operation on the stack deployment in HCP Terraform, or delete the stack entirely from the HCP Terraform UI.

## Stack Inputs

Inputs are provided per-deployment in `tfdeploy.hcl`:

| Variable | Description | Dev Default | Prod Default |
|----------|-------------|-------------|--------------|
| `role_arn` | AWS IAM role ARN for OIDC auth | — | — |
| `region` | AWS region | `ap-southeast-2` | `ap-southeast-2` |
| `cluster_name` | EKS cluster name | `eks-cluster-demo-dev` | `eks-cluster-demo-prod` |
| `cluster_version` | Kubernetes version | `1.31` | `1.31` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` | `10.1.0.0/16` |
| `instance_type` | Node instance type | `t3.medium` | `t3.large` |
| `node_min_size` | Min nodes | `1` | `2` |
| `node_max_size` | Max nodes | `3` | `6` |
| `node_desired_size` | Desired nodes | `2` | `3` |
| `environment` | Environment label | `development` | `production` |
| `vault_namespace` | K8s namespace for Vault | `vault` | `vault` |
| `vault_replicas` | Vault HA replicas | `3` | `5` |
| `vault_chart_version` | Vault Helm chart version | `0.29.1` | `0.29.1` |
| `vso_namespace` | K8s namespace for VSO | `vault-secrets-operator` | `vault-secrets-operator` |
| `vso_chart_version` | VSO Helm chart version | `0.9.1` | `0.9.1` |

## Stack Outputs

| Output | Description |
|--------|-------------|
| `cluster_name` | EKS cluster name |
| `cluster_endpoint` | Cluster API endpoint |
| `configure_kubectl` | Command to configure kubectl |
| `vault_namespace` | K8s namespace where Vault is deployed |
| `vso_namespace` | K8s namespace where VSO is deployed |
