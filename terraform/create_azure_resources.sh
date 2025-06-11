#!/bin/bash

# 변수 정의
RESOURCE_GROUP="rg-testbed"
LOCATION="koreacentral"
VNET1_NAME="vnet1"
VNET2_NAME="vnet2"
VNET3_NAME="vnet3"
VNET1_ADDRESS="10.1.0.0/16"
VNET2_ADDRESS="10.2.0.0/16"
VNET3_ADDRESS="10.3.0.0/16"
SUBNET_NAME="subnet-main"
SUBNET_PREFIX="/24"
VM1_NAME="vm-vnet1"
VM2_NAME="vm-vnet2"
VM3_NAME="vm-vnet3"
VM_SIZE="Standard_B2s"
KEY_NAME="osmgmt-key"
SSH_KEY_PATH="$HOME/.ssh/id_rsa.pub"

# 리소스 그룹 생성
az group create --name $RESOURCE_GROUP --location $LOCATION

# VNet 생성
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET1_NAME \
    --address-prefix $VNET1_ADDRESS \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix ${VNET1_ADDRESS%/*}$SUBNET_PREFIX

az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET2_NAME \
    --address-prefix $VNET2_ADDRESS \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix ${VNET2_ADDRESS%/*}$SUBNET_PREFIX

az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name $VNET3_NAME \
    --address-prefix $VNET3_ADDRESS \
    --subnet-name $SUBNET_NAME \
    --subnet-prefix ${VNET3_ADDRESS%/*}$SUBNET_PREFIX

# VNet 피어링 설정
# VNet1 <-> VNet2
az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET1_NAME \
    --name "${VNET1_NAME}-to-${VNET2_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET2_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET2_NAME \
    --name "${VNET2_NAME}-to-${VNET1_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET1_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

# VNet1 <-> VNet3
az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET1_NAME \
    --name "${VNET1_NAME}-to-${VNET3_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET3_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET3_NAME \
    --name "${VNET3_NAME}-to-${VNET1_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET1_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

# VNet2 <-> VNet3
az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET2_NAME \
    --name "${VNET2_NAME}-to-${VNET3_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET3_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

az network vnet peering create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name $VNET3_NAME \
    --name "${VNET3_NAME}-to-${VNET2_NAME}" \
    --remote-vnet $(az network vnet show --resource-group $RESOURCE_GROUP --name $VNET2_NAME --query id -o tsv) \
    --allow-vnet-access \
    --allow-forwarded-traffic

# VM 생성
# VM1 (VNet1)
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM1_NAME \
    --image Ubuntu2204 \
    --size $VM_SIZE \
    --vnet-name $VNET1_NAME \
    --subnet $SUBNET_NAME \
    --public-ip-address-allocation static \
    --admin-username azureuser \
    --ssh-key-values @$SSH_KEY_PATH \
    --authentication-type ssh \
    --os-disk-name "${VM1_NAME}-osdisk" \
    --nsg-rule SSH

# VM2 (VNet2)
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM2_NAME \
    --image Ubuntu2204 \
    --size $VM_SIZE \
    --vnet-name $VNET2_NAME \
    --subnet $SUBNET_NAME \
    --public-ip-address-allocation static \
    --admin-username azureuser \
    --ssh-key-values @$SSH_KEY_PATH \
    --authentication-type ssh \
    --os-disk-name "${VM2_NAME}-osdisk" \
    --nsg-rule SSH

# VM3 (VNet3)
az vm create \
    --resource-group $RESOURCE_GROUP \
    --name $VM3_NAME \
    --image Ubuntu2204 \
    --size $VM_SIZE \
    --vnet-name $VNET3_NAME \
    --subnet $SUBNET_NAME \
    --public-ip-address-allocation static \
    --admin-username azureuser \
    --ssh-key-values @$SSH_KEY_PATH \
    --authentication-type ssh \
    --os-disk-name "${VM3_NAME}-osdisk" \
    --nsg-rule SSH 