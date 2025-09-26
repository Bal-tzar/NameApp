#!/bin/bash

# Docker Swarm Setup Script
# This script will:
# 1. Initialize Docker Swarm on the manager node
# 2. Deploy your .NET MVC application as a service
# 3. Join all worker nodes to the swarm
# 4. Show the final status

set -e  # Exit on any error

# Configuration - EDIT THESE VALUES
MANAGER_IP="34.254.60.34"           # Public IP of your manager instance
WORKER_IPS=("3.254.79.155" "54.171.181.21")          # Array of worker public IPs, e.g. ("1.2.3.4" "5.6.7.8")
SSH_KEY_PATH="C:\Users\94ottdem\MyWinKey.pem"  # Path to your SSH private key file
SSH_USER="ec2-user"    # SSH username (ec2-user for Amazon Linux)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if configuration is set
check_config() {
    if [[ -z "$MANAGER_IP" ]]; then
        print_error "MANAGER_IP is not set. Please edit the script and set the manager's public IP."
        exit 1
    fi
    
    if [[ ${#WORKER_IPS[@]} -eq 0 ]]; then
        print_error "WORKER_IPS array is empty. Please add worker IP addresses."
        exit 1
    fi
    
    if [[ -z "$SSH_KEY_PATH" ]]; then
        print_error "SSH_KEY_PATH is not set. Please specify the path to your SSH private key."
        exit 1
    fi
    
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        print_error "SSH key file not found at: $SSH_KEY_PATH"
        exit 1
    fi
}

# Function to test SSH connectivity
test_ssh() {
    local ip=$1
    local role=$2
    print_status "Testing SSH connectivity to $role ($ip)..."
    
    if ssh -i "$SSH_KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$SSH_USER@$ip" "echo 'SSH test successful'" >/dev/null 2>&1; then
        print_success "SSH connectivity to $role ($ip) - OK"
        return 0
    else
        print_error "Cannot connect to $role ($ip) via SSH"
        return 1
    fi
}

# Function to setup Docker on a node
setup_docker() {
    local ip=$1
    local role=$2
    
    print_status "Setting up Docker on $role ($ip)..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$ip" << 'EOF'
        # Update system and install Docker
        sudo yum update -y >/dev/null 2>&1
        sudo yum install -y docker >/dev/null 2>&1
        
        # Start and enable Docker
        sudo systemctl enable docker >/dev/null 2>&1
        sudo systemctl start docker >/dev/null 2>&1
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        echo "Docker setup completed"
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Docker setup completed on $role ($ip)"
    else
        print_error "Failed to setup Docker on $role ($ip)"
        return 1
    fi
}

# Function to initialize swarm on manager
init_swarm_manager() {
    print_status "Initializing Docker Swarm on manager ($MANAGER_IP)..."
    
    # Get the private IP of the manager
    MANAGER_PRIVATE_IP=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" "curl -s http://169.254.169.254/latest/meta-data/local-ipv4")
    
    if [[ -z "$MANAGER_PRIVATE_IP" ]]; then
        print_error "Failed to get manager private IP"
        exit 1
    fi
    
    print_status "Manager private IP: $MANAGER_PRIVATE_IP"
    
    # Initialize swarm first
    print_status "Initializing Docker Swarm..."
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" << EOF
        # Leave any existing swarm first
        docker swarm leave --force >/dev/null 2>&1 || true
        
        # Wait a moment
        sleep 2
        
        # Initialize Docker Swarm
        docker swarm init --advertise-addr $MANAGER_PRIVATE_IP
EOF
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to initialize swarm"
        exit 1
    fi
    
    print_success "Swarm initialized successfully"
    
    # Now get the join token
    print_status "Getting worker join token..."
    WORKER_JOIN_TOKEN=$(ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" "docker swarm join-token worker -q")
    
    if [[ -z "$WORKER_JOIN_TOKEN" ]]; then
        print_error "Failed to get worker join token"
        exit 1
    fi
    
    print_status "Worker join token retrieved successfully"
}

# Function to deploy the application service
deploy_application() {
    print_status "Deploying nameapp service on the swarm..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" << 'EOF'
        # Remove existing service if it exists
        docker service rm nameapp >/dev/null 2>&1 || true
        
        # Wait a moment for cleanup
        sleep 5
        
        # Create the service (allow on any node since we might not have workers joined yet)
        docker service create \
            --name nameapp \
            --replicas 2 \
            --publish 80:80 \
            --update-parallelism 1 \
            --update-delay 10s \
            --restart-condition on-failure \
            baltzar1994/nameapp:latest
        
        echo "Service deployment initiated"
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Application service deployed"
    else
        print_warning "Service deployment may have failed, but continuing..."
    fi
}

# Function to update service to run on workers only
update_service_constraints() {
    print_status "Updating service to run on worker nodes only..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" << 'EOF'
        # Update the service to only run on worker nodes
        docker service update \
            --constraint-add 'node.role == worker' \
            nameapp >/dev/null 2>&1 || true
        
        echo "Service constraints updated"
EOF
    
    print_success "Service updated to run on workers only"
}

# Function to join worker to swarm
join_worker() {
    local worker_ip=$1
    local worker_num=$2
    
    print_status "Joining worker $worker_num ($worker_ip) to the swarm..."
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$worker_ip" << EOF
        # Leave any existing swarm first
        docker swarm leave --force >/dev/null 2>&1 || true
        
        # Wait a moment
        sleep 2
        
        # Join the swarm
        docker swarm join --token $WORKER_JOIN_TOKEN $MANAGER_PRIVATE_IP:2377
EOF
    
    if [[ $? -eq 0 ]]; then
        print_success "Worker $worker_num ($worker_ip) joined the swarm successfully"
    else
        print_error "Failed to join worker $worker_num ($worker_ip) to the swarm"
        return 1
    fi
}

# Function to show swarm status
show_swarm_status() {
    print_status "Checking swarm status..."
    
    echo -e "\n${BLUE}=== SWARM NODES ===${NC}"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" "docker node ls"
    
    echo -e "\n${BLUE}=== SERVICES ===${NC}"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" "docker service ls"
    
    echo -e "\n${BLUE}=== SERVICE DETAILS ===${NC}"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -T "$SSH_USER@$MANAGER_IP" "docker service ps nameapp"
    
    echo -e "\n${GREEN}=== SETUP COMPLETE ===${NC}"
    echo -e "Your .NET MVC application should be accessible at:"
    echo -e "  http://$MANAGER_IP"
    for worker_ip in "${WORKER_IPS[@]}"; do
        echo -e "  http://$worker_ip"
    done
}

# Main execution
main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}    Docker Swarm Setup Script${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    
    # Check configuration
    check_config
    
    # Test SSH connectivity
    print_status "Testing SSH connectivity to all nodes..."
    test_ssh "$MANAGER_IP" "manager"
    
    for i in "${!WORKER_IPS[@]}"; do
        test_ssh "${WORKER_IPS[$i]}" "worker $((i+1))"
    done
    
    echo ""
    
    # Setup Docker on all nodes
    print_status "Setting up Docker on all nodes..."
    setup_docker "$MANAGER_IP" "manager"
    
    for i in "${!WORKER_IPS[@]}"; do
        setup_docker "${WORKER_IPS[$i]}" "worker $((i+1))"
    done
    
    # Small delay to ensure Docker is ready
    print_status "Waiting for Docker to be ready..."
    sleep 5
    
    # Initialize swarm on manager
    init_swarm_manager
    
    # Join workers to swarm
    print_status "Adding workers to the swarm..."
    for i in "${!WORKER_IPS[@]}"; do
        join_worker "${WORKER_IPS[$i]}" "$((i+1))"
        sleep 2  # Small delay between joins
    done
    
    # Deploy application after workers are joined
    deploy_application
    
    # Update service to run on workers only
    update_service_constraints
    
    # Wait for services to be ready
    print_status "Waiting for services to become ready..."
    sleep 10
    
    # Show final status
    show_swarm_status
    
    echo ""
    echo -e "${GREEN}🎉 Docker Swarm setup completed successfully!${NC}"
}

# Help function
show_help() {
    echo "Docker Swarm Setup Script"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Before running this script, you must edit the configuration section at the top:"
    echo "  - MANAGER_IP: Public IP address of your manager instance"
    echo "  - WORKER_IPS: Array of worker public IP addresses"
    echo "  - SSH_KEY_PATH: Path to your SSH private key file"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -s, --status   Show current swarm status (requires manager IP to be set)"
    echo ""
    echo "Example configuration:"
    echo '  MANAGER_IP="3.250.123.45"'
    echo '  WORKER_IPS=("3.250.123.46" "3.250.123.47")'
    echo '  SSH_KEY_PATH="~/.ssh/MyWinKey.pem"'
}

# Status check function
check_status() {
    if [[ -z "$MANAGER_IP" ]]; then
        print_error "MANAGER_IP is not set. Please edit the script first."
        exit 1
    fi
    
    print_status "Checking swarm status on $MANAGER_IP..."
    show_swarm_status
}

# Handle command line arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    -s|--status)
        check_status
        exit 0
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use -h or --help for usage information"
        exit 1
        ;;
esac