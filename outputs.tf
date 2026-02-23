output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data for the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "vault_namespace" {
  description = "Kubernetes namespace where Vault is deployed"
  value       = kubernetes_namespace.vault.metadata[0].name
}

output "vault_address" {
  description = "Command to get the Vault service address"
  value       = "kubectl get svc -n ${var.vault_namespace} vault -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "vso_namespace" {
  description = "Kubernetes namespace where the Vault Secrets Operator is deployed"
  value       = kubernetes_namespace.vault_secrets_operator.metadata[0].name
}

output "vso_demo_namespace" {
  description = "Kubernetes namespace for the Vault Secrets Operator demonstration"
  value       = kubernetes_namespace.vso_demo.metadata[0].name
}
