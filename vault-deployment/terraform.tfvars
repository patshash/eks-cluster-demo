# Get cluster_name from infrastructure/terraform output
# Run: cd ../infrastructure && terraform output cluster_name
cluster_name        = "eks-cluster-demo"
region              = "ap-southeast-2"
vault_namespace     = "vault"
vault_chart_version = "0.27.0"
vault_replicas      = 3
vso_namespace       = "vault-secrets-operator"
vso_chart_version   = "0.7.1"
