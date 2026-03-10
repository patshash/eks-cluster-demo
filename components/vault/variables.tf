variable "vault_namespace" {
  description = "Kubernetes namespace to deploy Vault into"
  type        = string
  default     = "vault"
}

variable "vault_replicas" {
  description = "Number of Vault server replicas (HA mode)"
  type        = number
  default     = 3
}

variable "vault_chart_version" {
  description = "Version of the HashiCorp Vault Helm chart"
  type        = string
  default     = "0.29.1"
}

variable "vso_namespace" {
  description = "Kubernetes namespace to deploy the Vault Secrets Operator into"
  type        = string
  default     = "vault-secrets-operator"
}

variable "vso_chart_version" {
  description = "Version of the Vault Secrets Operator Helm chart"
  type        = string
  default     = "0.9.1"
}
