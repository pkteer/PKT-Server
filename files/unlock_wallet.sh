#!/bin/bash
unlock=$(curl -X POST -H "Content-Type: application/json" -d '{ "wallet_passphrase":"'$PKTEER_SECRET'"}' http://localhost:8080/api/v1/wallet/unlock)i