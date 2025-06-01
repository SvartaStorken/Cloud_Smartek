#!/bin/bash

echo ">>> Applying Terraform configuration..."
terraform apply -auto-approve

if [ $? -ne 0 ]; then
  echo "Terraform apply failed!"
  exit 1
fi

echo ">>> Fetching IP addresses from Terraform output..."
NGINX_PUBLIC_IP=$(terraform output -raw nginx_vm_public_ip_address)
MARIADB_PRIVATE_IP=$(terraform output -raw mariadb_vm_private_ip_address)
MONGODB_PRIVATE_IP=$(terraform output -raw mongodb_vm_private_ip_address)
WORDPRESS_PRIVATE_IP=$(terraform output -raw wordpress_vm_private_ip_address)
MINIO_PRIVATE_IP=$(terraform output -raw minio_vm_private_ip_address)

if [ -z "$NGINX_PUBLIC_IP" ] || [ -z "$MARIADB_PRIVATE_IP" ]; then
  echo "Failed to get IP addresses from Terraform output!"
  exit 1
fi

echo "Nginx Public IP: $NGINX_PUBLIC_IP"
echo "MariaDB Private IP: $MARIADB_PRIVATE_IP"
echo "Word press private IP: $WORDPRESS_PRIVATE_IP"
echo "Mongodb private IP: $MONGODB_PRIVATE_IP"
echo "MinIO private IP: $MINIO_PRIVATE_IP"

echo "********************"
echo ">>> SSH to Nginx_vm"
ssh azureuser@$NGINX_PUBLIC_IP df -h
echo "********************"
ssh azureuser@$NGINX_PUBLIC_IP free
echo "********************"
ssh azureuser@$NGINX_PUBLIC_IP lscpu
echo "********************"

# Definiera sökvägen till Ansible och variabel-filen
ANSIBLE_DIR=ansible
GROUP_VARS_ALL_DIR="$ANSIBLE_DIR/group_vars/all"
IP_VARS_FILE="$GROUP_VARS_ALL_DIR/generated_ips.yml"

# Skapa group_vars/all katalogen om den inte finns
mkdir -p "$GROUP_VARS_ALL_DIR"

echo ">>> Writing IP addresses to Ansible vars file: $IP_VARS_FILE"
cat << EOF > "$IP_VARS_FILE"
---
# Denna fil genereras automatiskt av deploy.sh
# Ändra inte manuellt, då ändringar skrivs över.

nginx_ip: "$NGINX_PUBLIC_IP"
mariadb_ip: "$MARIADB_PRIVATE_IP"
wordpress_ip: "$WORDPRESS_PRIVATE_IP"
mongodb_ip: "$MONGODB_PRIVATE_IP"
minio_ip: "$MINIO_PRIVATE_IP"
EOF

# Navigera till Ansible-katalogen
cd "$ANSIBLE_DIR"

echo ">>> Running Ansible playbook..."
# --extra-vars behövs inte längre, då variablerna läses från group_vars/all/generated_ips.yml
ansible-playbook -i inventory.ini update_install_nginx.yml

echo ">>> Deployment finished."
