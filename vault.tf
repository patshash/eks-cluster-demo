resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault_namespace

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  version    = var.vault_chart_version
  namespace  = kubernetes_namespace.vault.metadata[0].name

  set {
    name  = "server.ha.enabled"
    value = "true"
  }

  set {
    name  = "server.ha.replicas"
    value = tostring(var.vault_replicas)
  }

  set {
    name  = "server.ha.raft.enabled"
    value = "true"
  }

  set {
    name  = "injector.enabled"
    value = "true"
  }

  depends_on = [kubernetes_namespace.vault]
}
