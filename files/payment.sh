#!/bin/bash

pay_to_address=$(jq -r '.pkt.pay_to_address' /data/config.json)
if [ -z "$pay_to_address" ]; then
  echo "pay_to_address is empty. Exiting..."
  exit 1
fi
# Get balances from the wallet
pldctl="/server/pktd/bin/pldctl"
balances_output=$($pldctl wallet/address/balances)
addresses=$(echo "$balances_output" | jq -r '.addrs[] | "\(.address)"')
balances=$(echo "$balances_output" | jq -r '.addrs[] | "\(.total)"')

IFS=$'\n' read -d '' -r -a address_array <<< "$addresses"
IFS=$'\n' read -d '' -r -a balance_array <<< "$balances"

# Iterate through the arrays and print the address and total balance
for i in "${!address_array[@]}"; do
    echo "Address: ${address_array[$i]}, Total Balance: ${balance_array[$i]}"
    echo "Making payment to $pay_to_address from ${address_array[$i]} for amount of ${balance_array[$i]}"
    payment_output=$($pldctl wallet/transaction/sendfrom --to_address=$pay_to_address --amount=${balance_array[$i]} --from_address='["'${address_array[$i]}'"]')
    echo "$payment_output" >> /data/payments.json
done
