data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "server.ha.enabled"
    value = "false"
  }

  set {
    name  = "server.ha.replicas"
    value = tostring(var.vault_replicas)
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "false"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  set {
    name  = "server.dataStorage.enabled"
    value = "false"
  }

  set {
    name  = "server.auditStorage.enabled"
    value = "false"
  }

  depends_on = [kubernetes_namespace.vault]
}

resource "kubernetes_namespace" "vault_secrets_operator" {
  metadata {
    name = var.vso_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

resource "helm_release" "vault_secrets_operator" {
  name       = "vault-secrets-operator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  version    = var.vso_chart_version
  namespace  = kubernetes_namespace.vault_secrets_operator.metadata[0].name

  set {
    name  = "defaultVaultConnection.enabled"
    value = "true"
  }

  set {
    name  = "defaultVaultConnection.address"
    value = "http://vault.${var.vault_namespace}.svc.cluster.local:8200"
  }

  depends_on = [kubernetes_namespace.vault_secrets_operator, helm_release.vault]
}

# Demo namespace for the Vault Secrets Operator example
resource "kubernetes_namespace" "vso_demo" {
  metadata {
    name = "vso-demo"

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }
}

# Service account used by the demo application and referenced by VaultAuth
resource "kubernetes_service_account" "vso_demo" {
  metadata {
    name      = "demo-sa"
    namespace = kubernetes_namespace.vso_demo.metadata[0].name
  }
}
