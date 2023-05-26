#!/bin/bash
PKTEER_WALLET_PASSPHRASE="password"
# Generate seed
echo "Generating seed..."
seed=$(curl -X POST -H "Content-Type: application/json" -d '{}' http://localhost:8080/api/v1/util/seed/create)
arr=$(echo $seed | jq -r '.seed[]')
echo "**************** THIS IS IMPORTANT - SAVE THIS SEED! ****************"
echo "Your PKT Wallet seed is: $arr"
echo "**************** THIS IS IMPORTANT - SAVE THIS SEED! ****************"
wallet_seed_json=$(printf '%s\n' "${arr[@]}" | jq -R . | jq -s .)
json=$(echo '{}' | jq --argjson wallet_seed "$wallet_seed_json" \
                      --arg passphrase "$PKTEER_WALLET_PASSPHRASE" \
                      --arg name 'wallet.db' \
                      '.wallet_seed=$wallet_seed | .wallet_passphrase=$passphrase | .wallet_name=$name')

# Create Wallet
echo "Creating wallet with password: $PKTEER_WALLET_PASSPHRASE"
wallet=$(curl -X POST -H "Content-Type: application/json" -d "$json" http://localhost:8080/api/v1/wallet/create)
echo "Response: $wallet"

