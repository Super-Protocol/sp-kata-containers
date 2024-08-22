#!/bin/bash

keys_dir="/etc/ssh/keys"
rsa_key="${keys_dir}/ssh_host_rsa_key"
ecdsa_key="${keys_dir}/ssh_host_ecdsa_key"
ed25519_key="${keys_dir}/ssh_host_ed25519_key"

if [ ! -f "$rsa_key" ]; then
    ssh-keygen -t rsa -f "$rsa_key" -N ''
fi

if [ ! -f "$ecdsa_key" ]; then
    ssh-keygen -t ecdsa -f "$ecdsa_key" -N ''
fi

if [ ! -f "$ed25519_key" ]; then
    ssh-keygen -t ed25519 -f "$ed25519_key" -N ''
fi
