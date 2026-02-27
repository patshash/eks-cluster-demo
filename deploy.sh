#!/bin/bash
# Deployment automation script for EKS + Vault using refactored Terraform

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGION="${AWS_REGION:-ap-southeast-2}"
CLUSTER_NAME="${CLUSTER_NAME:-eks-cluster-demo}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    command -v terraform >/dev/null 2>&1 || { log_error "terraform is not installed"; exit 1; }
    command -v aws >/dev/null 2>&1 || { log_error "aws CLI is not installed"; exit 1; }
    command -v kubectl >/dev/null 2>&1 || { log_error "kubectl is not installed"; exit 1; }
    command -v helm >/dev/null 2>&1 || { log_error "helm is not installed"; exit 1; }
    command -v doormat >/dev/null 2>&1 || { log_error "doormat is not installed"; exit 1; }
    
    log_info "All prerequisites met"
}

# Authenticate with doormat
authenticate() {
    log_info "Authenticating with doormat..."
    doormat login
    eval "$(doormat aws export --role arn:aws:iam::702923778565:role/aws_pcarey_test-developer)"
    log_info "AWS credentials configured"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying EKS infrastructure..."
    
    cd "$SCRIPT_DIR/infrastructure"
    
    if [ ! -f terraform.tfvars ]; then
        log_warn "terraform.tfvars not found, creating from example..."
        cp terraform.tfvars.example terraform.tfvars
        log_warn "Please review and update terraform.tfvars as needed"
    fi
    
    terraform init
    terraform plan -out=tfplan
    
    log_warn "Review the plan above. Continue with deployment? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    terraform apply tfplan
    
    CLUSTER_NAME=$(terraform output -raw cluster_name)
    log_info "Infrastructure deployed successfully"
    log_info "Cluster name: $CLUSTER_NAME"
}

# Configure kubectl
configure_kubectl() {
    log_info "Configuring kubectl..."
    
    KUBECONFIG_CMD="aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME"
    eval "$KUBECONFIG_CMD"
    
    log_info "Waiting for node group to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=Ready nodes --all --timeout=15m 2>/dev/null || true
    
    log_info "kubectl configured for cluster: $CLUSTER_NAME"
}

# Deploy Vault
deploy_vault() {
    log_info "Deploying Vault and Vault Secrets Operator..."
    
    cd "$SCRIPT_DIR/vault-deployment"
    
    if [ ! -f terraform.tfvars ]; then
        log_info "Creating terraform.tfvars for vault deployment..."
        cat > terraform.tfvars <<EOF
cluster_name = "$CLUSTER_NAME"
region       = "$REGION"
EOF
        log_info "terraform.tfvars created"
    fi
    
    terraform init
    terraform plan -out=tfplan
    
    log_warn "Review the plan above. Continue with deployment? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    terraform apply tfplan
    log_info "Vault deployment successful"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying deployment..."
    
    log_info "Checking EKS cluster..."
    kubectl cluster-info
    
    log_info "Checking node status..."
    kubectl get nodes
    
    log_info "Checking Vault pods..."
    kubectl get pods -n vault
    
    log_info "Checking Vault Secrets Operator pods..."
    kubectl get pods -n vault-secrets-operator
    
    log_info "Checking demo namespace..."
    kubectl get pods -n vso-demo || log_warn "vso-demo namespace may not have pods yet"
}

# Display post-deployment instructions
post_deployment_info() {
    log_info "Deployment complete!"
    log_info ""
    log_info "Next steps:"
    log_info "1. Initialize Vault:"
    log_info "   kubectl exec -it vault-0 -n vault -- vault operator init"
    log_info "   kubectl exec -it vault-0 -n vault -- vault operator unseal"
    log_info ""
    log_info "2. Configure Kubernetes auth method in Vault"
    log_info "3. Create test secrets in Vault"
    log_info "4. Uncomment VSO demo resources in vault-deployment/main.tf"
    log_info ""
    log_info "For more information, see REFACTORED_README.md"
}

# Main execution
main() {
    log_info "Starting EKS + Vault deployment..."
    
    case "${1:-full}" in
        infra)
            check_prerequisites
            authenticate
            deploy_infrastructure
            ;;
        vault)
            check_prerequisites
            authenticate
            configure_kubectl
            deploy_vault
            ;;
        verify)
            check_prerequisites
            authenticate
            configure_kubectl
            verify_deployment
            ;;
        full)
            check_prerequisites
            authenticate
            deploy_infrastructure
            configure_kubectl
            deploy_vault
            verify_deployment
            post_deployment_info
            ;;
        destroy)
            log_warn "This will destroy all Vault and infrastructure resources"
            read -p "Are you sure? Type 'destroy' to confirm: " confirm
            if [ "$confirm" != "destroy" ]; then
                log_info "Destroy cancelled"
                exit 0
            fi
            authenticate
            
            log_info "Destroying Vault deployment..."
            cd "$SCRIPT_DIR/vault-deployment"
            terraform destroy -auto-approve
            
            log_info "Destroying infrastructure..."
            cd "$SCRIPT_DIR/infrastructure"
            terraform destroy -auto-approve
            
            log_info "Destruction complete"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Usage: $0 {full|infra|vault|verify|destroy}"
            exit 1
            ;;
    esac
}

main "$@"
