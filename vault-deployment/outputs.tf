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
