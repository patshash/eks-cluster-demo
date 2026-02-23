# Demo namespace for the Vault Secrets Operator example
resource "kubernetes_namespace" "vso_demo" {
  metadata {
    name = "vso-demo"

    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
    }
  }

  depends_on = [module.eks]
}

# Service account used by the demo application and referenced by VaultAuth
resource "kubernetes_service_account" "vso_demo" {
  metadata {
    name      = "demo-sa"
    namespace = kubernetes_namespace.vso_demo.metadata[0].name
  }
}

# VaultConnection: points the operator at the in-cluster Vault server
resource "kubernetes_manifest" "vault_connection_demo" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultConnection"
    metadata = {
      name      = "default"
      namespace = kubernetes_namespace.vso_demo.metadata[0].name
    }
    spec = {
      address       = "http://vault.${var.vault_namespace}.svc.cluster.local:8200"
      skipTLSVerify = true
    }
  }

  depends_on = [helm_release.vault_secrets_operator]
}

# VaultAuth: defines how VSO authenticates to Vault using the Kubernetes auth method.
# Vault must be initialized and the Kubernetes auth method enabled before this becomes active.
# See README.md for the required Vault-side configuration steps.
resource "kubernetes_manifest" "vault_auth_demo" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "demo-auth"
      namespace = kubernetes_namespace.vso_demo.metadata[0].name
    }
    spec = {
      vaultConnectionRef = "default"
      method             = "kubernetes"
      mount              = "kubernetes"
      kubernetes = {
        role           = "demo-role"
        serviceAccount = kubernetes_service_account.vso_demo.metadata[0].name
        audiences      = ["vault"]
      }
    }
  }

  depends_on = [kubernetes_manifest.vault_connection_demo, kubernetes_service_account.vso_demo]
}

# VaultStaticSecret: instructs VSO to sync a KV v2 secret into a Kubernetes Secret
resource "kubernetes_manifest" "vault_static_secret_demo" {
  manifest = {
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "demo-secret"
      namespace = kubernetes_namespace.vso_demo.metadata[0].name
    }
    spec = {
      vaultAuthRef = "demo-auth"
      mount        = "secret"
      type         = "kv-v2"
      path         = "demo/config"
      destination = {
        name   = "demo-secret"
        create = true
      }
      refreshAfter = "30s"
    }
  }

  depends_on = [kubernetes_manifest.vault_auth_demo]
}

# Demo deployment: consumes the VSO-synced Kubernetes Secret as environment variables
resource "kubernetes_deployment" "vso_demo" {
  metadata {
    name      = "vso-demo"
    namespace = kubernetes_namespace.vso_demo.metadata[0].name
    labels = {
      app = "vso-demo"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "vso-demo"
      }
    }

    template {
      metadata {
        labels = {
          app = "vso-demo"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.vso_demo.metadata[0].name

        container {
          name  = "demo"
          image = "busybox:1.36"
          command = ["sh", "-c", "while true; do echo 'Synced secret keys:'; env | grep -i secret | cut -d'=' -f1 || echo '(no secret keys found yet)'; sleep 30; done"]

          env_from {
            secret_ref {
              name     = "demo-secret"
              optional = true
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.vault_static_secret_demo]
}
