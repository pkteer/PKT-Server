#!/bin/bash

# Generate seed
echo "Generating seed..."
seed=$(curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8080/api/v1/util/seed/create)
arr=$(echo $seed | jq -r '.seed[]')
echo "PKT Wallet Seed: $arr"
wallet_seed_json=$(printf '%s\n' "${arr[@]}" | jq -R . | jq -s .)
json=$(echo '{}' | jq --argjson wallet_seed "$wallet_seed_json" \
                      --arg passphrase "$PKTEER_SECRET" \
                      --arg name 'mywallet.db' \
                      '.wallet_seed=$wallet_seed | .wallet_passphrase=$passphrase | .wallet_name=$name')

# Create Wallet
echo "Creating wallet with password: $PKTEER_SECRET"
wallet=$(curl -X POST -H "Content-Type: application/json" -d "$json" http://localhost:8080/api/v1/wallet/create)
echo "Response: $wallet"

