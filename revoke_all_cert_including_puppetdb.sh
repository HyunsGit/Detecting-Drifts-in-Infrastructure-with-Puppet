#!/bin/bash

NODES=(
  "node01.internal.example.com"
)

MASTER_FQDN="puppet-master.internal.example.com"
MASTER_CERT="/var/lib/puppet/ssl/certs/${MASTER_FQDN}.pem"
MASTER_KEY="/var/lib/puppet/ssl/private_keys/${MASTER_FQDN}.pem"
CA_CERT="/etc/puppet/puppetserver/ca/ca_crt.pem"

for node in "${NODES[@]}"; do
  echo "=== Removing: $node ==="

  # Deactivate in PuppetDB
  curl -X POST https://${MASTER_FQDN}:8081/pdb/cmd/v1 \
    -H 'Content-Type: application/json' \
    --cacert "$CA_CERT" --cert "$MASTER_CERT" --key "$MASTER_KEY" \
    -d '{
      "command": "deactivate node",
      "version": 3,
      "payload": {
        "certname": "'"$node"'",
        "producer_timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'"
      }
    }'

  echo ""

  # Revoke and clean certificate
  sudo puppetserver ca revoke --certname "$node"
  sudo puppetserver ca clean --certname "$node"

  echo "=== Done: $node ==="
  echo ""
done
