#!/usr/bin/env bash
# Operator side of onboarding: sign a participant's CSR with the CA,
# producing their certificate. This signature is the actual "sign up"
# moment -- it's the CA vouching that the public key in the CSR belongs to
# the named participant. Nothing about the exchange's own code needs to
# change for this to happen; the CA's signature is the only "registration"
# that exists.
set -euo pipefail
cd "$(dirname "$0")"

name="${1:?usage: sign_participant.sh <name>}"

openssl x509 -req -in "${name}.csr" -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out "${name}.crt" -days 3650 -sha256

rm -f "${name}.csr"
echo "Signed ${name}.crt using the CA. Hand this back to ${name} along with ca.crt."
