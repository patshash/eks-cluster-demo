required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"
  }
  kubernetes = {
    source  = "hashicorp/kubernetes"
    version = "~> 2.0"
  }
  helm = {
    source  = "hashicorp/helm"
    version = "~> 2.0"
  }
}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------

variable "aws_identity_token" {
  type      = string
  ephemeral = true
}

variable "role_arn" {
  type = string
}

variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "cluster_name" {
  type    = string
  default = "eks-cluster-demo"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "environment" {
  type    = string
  default = "demo"
}

variable "vault_namespace" {
  type    = string
  default = "vault"
}

variable "vault_replicas" {
  type    = number
  default = 3
}

variable "vault_chart_version" {
  type    = string
  default = "0.29.1"
}

variable "vso_namespace" {
  type    = string
  default = "vault-secrets-operator"
}

variable "vso_chart_version" {
  type    = string
  default = "0.9.1"
}

# ---------------------------------------------------------------------------
# Providers
# ---------------------------------------------------------------------------

provider "aws" "this" {
  config {
    region = var.region

    assume_role_with_web_identity {
      role_arn                = var.role_arn
      web_identity_token      = var.aws_identity_token
    }
  }
}

provider "kubernetes" "this" {
  config {
    host                   = component.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(component.eks.cluster_certificate_authority_data)
    token                  = component.eks.cluster_token
  }
}

provider "helm" "this" {
  config {
    kubernetes {
      host                   = component.eks.cluster_endpoint
      cluster_ca_certificate = base64decode(component.eks.cluster_certificate_authority_data)
      token                  = component.eks.cluster_token
    }
  }
}

# ---------------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------------

component "networking" {
  source = "./components/networking"

  inputs = {
    region       = var.region
    cluster_name = var.cluster_name
    vpc_cidr     = var.vpc_cidr
    environment  = var.environment
  }

  providers = {
    aws = provider.aws.this
  }
}

component "eks" {
  source = "./components/eks"

  inputs = {
    cluster_name      = var.cluster_name
    cluster_version   = var.cluster_version
    vpc_id            = component.networking.vpc_id
    subnet_ids        = component.networking.private_subnets
    instance_type     = var.instance_type
    node_min_size     = var.node_min_size
    node_max_size     = var.node_max_size
    node_desired_size = var.node_desired_size
    environment       = var.environment
  }

  providers = {
    aws = provider.aws.this
  }
}

component "vault" {
  source = "./components/vault"

  inputs = {
    vault_namespace     = var.vault_namespace
    vault_replicas      = var.vault_replicas
    vault_chart_version = var.vault_chart_version
    vso_namespace       = var.vso_namespace
    vso_chart_version   = var.vso_chart_version
  }

  providers = {
    kubernetes = provider.kubernetes.this
    helm       = provider.helm.this
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "cluster_name" {
  type  = string
  value = component.eks.cluster_name
}

output "cluster_endpoint" {
  type  = string
  value = component.eks.cluster_endpoint
}

output "configure_kubectl" {
  type  = string
  value = "aws eks update-kubeconfig --region ${var.region} --name ${component.eks.cluster_name}"
}

output "vault_namespace" {
  type  = string
  value = component.vault.vault_namespace
}

output "vso_namespace" {
  type  = string
  value = component.vault.vso_namespace
}
