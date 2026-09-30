#!/usr/bin/env bash

PREFIX=khikmatov-02
ZONE=ru-central1-b
CIDR=10.12.1.0/24
DISK_SIZE=20
IMAGE_FAMILY=ubuntu-2204-lts
VM_COUNT=2

yc vpc network create --name "$PREFIX-net" --labels created-by=script
yc vpc subnet create \
  --name "$PREFIX-subnet" \
  --network-name "$PREFIX-net" \
  --zone "$ZONE" \
  --range "$CIDR"

for i in $(seq 1 "$VM_COUNT"); do
  yc compute instance create \
    --name "$PREFIX-app-$i" \
    --zone "$ZONE" \
    --platform standard-v3 \
    --cores=2 --core-fraction=20 --memory=2 \
    --preemptible \
    --create-boot-disk image-folder-id=standard-images,image-family="$IMAGE_FAMILY",type=network-hdd,size="$DISK_SIZE" \
    --network-interface subnet-name="$PREFIX-subnet",nat-ip-version=ipv4 \
    --hostname "$PREFIX-app-$i" \
    --ssh-key ~/.ssh/id_ed25519.pub \
    --labels created-by=script
done

for i in $(seq 1 "$VM_COUNT"); do
  IP=$(yc compute instance get "$PREFIX-app-$i" --format json \
    | jq -r '.network_interfaces[0].primary_v4_address.one_to_one_nat.address')
  echo "$PREFIX-app-$i  $IP"
done