variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "cluster_name" {
  description = "EKS cluster name (from infrastructure deployment)"
  type        = string
}

variable "vault_namespace" {
  description = "Kubernetes namespace for Vault"
  type        = string
  default     = "vault"
}

variable "vault_chart_version" {
  description = "Helm chart version for Vault"
  type        = string
  default     = "0.27.0"
}

variable "vault_replicas" {
  description = "Number of Vault replicas"
  type        = number
  default     = 3
}

variable "vso_namespace" {
  description = "Kubernetes namespace for Vault Secrets Operator"
  type        = string
  default     = "vault-secrets-operator"
}

variable "vso_chart_version" {
  description = "Helm chart version for Vault Secrets Operator"
  type        = string
  default     = "0.7.1"
}
