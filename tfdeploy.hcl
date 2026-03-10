identity_token "aws" {
  audience = ["aws.workload.identity"]
}

deployment "development" {
  inputs = {
    aws_identity_token = identity_token.aws.jwt
    role_arn           = "<REPLACE_WITH_AWS_ROLE_ARN>"
    region             = "ap-southeast-2"
    cluster_name       = "eks-cluster-demo-dev"
    cluster_version    = "1.31"
    vpc_cidr           = "10.0.0.0/16"
    instance_type      = "t3.medium"
    node_min_size      = 1
    node_max_size      = 3
    node_desired_size  = 2
    environment        = "development"
    vault_namespace    = "vault"
    vault_replicas     = 3
    vault_chart_version = "0.29.1"
    vso_namespace      = "vault-secrets-operator"
    vso_chart_version  = "0.9.1"
  }
}

deployment "production" {
  inputs = {
    aws_identity_token = identity_token.aws.jwt
    role_arn           = "<REPLACE_WITH_AWS_ROLE_ARN>"
    region             = "ap-southeast-2"
    cluster_name       = "eks-cluster-demo-prod"
    cluster_version    = "1.31"
    vpc_cidr           = "10.1.0.0/16"
    instance_type      = "t3.large"
    node_min_size      = 2
    node_max_size      = 6
    node_desired_size  = 3
    environment        = "production"
    vault_namespace    = "vault"
    vault_replicas     = 5
    vault_chart_version = "0.29.1"
    vso_namespace      = "vault-secrets-operator"
    vso_chart_version  = "0.9.1"
  }
}
