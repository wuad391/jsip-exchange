#!/usr/bin/env bash
# Participant side of onboarding: generate a private key and a certificate
# signing request (CSR) for <name>. The private key never leaves this step
# -- only the CSR (a public request, no secret in it) should be handed to
# whoever runs the CA for signing (see sign_participant.sh).
set -euo pipefail
cd "$(dirname "$0")"

name="${1:?usage: new_participant_request.sh <name>}"

openssl req -newkey rsa:2048 -sha256 -nodes \
  -keyout "${name}.key" -out "${name}.csr" \
  -subj "/CN=${name}"

echo "Created ${name}.key (keep private) and ${name}.csr (hand this to the operator to sign)."
