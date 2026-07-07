#!/usr/bin/env bash
# A second, unrelated CA, used only to build a certificate that's signed by
# *someone* but not by our real CA (ca.crt). Exists purely as a fixture for
# the "wrong CA is rejected" test -- nothing here is ever meant to be
# trusted by the exchange server.
set -euo pipefail
cd "$(dirname "$0")"

if [[ -f rogue_ca.key && -f rogue_ca.crt ]]; then
  echo "Rogue CA already exists (rogue_ca.key, rogue_ca.crt) -- skipping."
else
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout rogue_ca.key -out rogue_ca.crt -subj "/CN=Not The Real CA"
  echo "Created rogue CA: rogue_ca.key, rogue_ca.crt"
fi

if [[ -f rogue.key && -f rogue.crt ]]; then
  echo "Rogue cert already exists (rogue.key, rogue.crt) -- skipping."
else
  # Deliberately claims CN=Alice: the point of this fixture is that a
  # correctly-shaped certificate claiming to be a real participant is still
  # rejected once it's signed by the wrong CA -- trust comes from the
  # signature, not from the name written on the cert.
  openssl req -newkey rsa:2048 -sha256 -nodes \
    -keyout rogue.key -out rogue.csr -subj "/CN=Alice"
  openssl x509 -req -in rogue.csr -CA rogue_ca.crt -CAkey rogue_ca.key \
    -CAcreateserial -out rogue.crt -days 3650 -sha256
  rm -f rogue.csr
  echo "Created rogue.crt (CN=Alice, signed by the rogue CA, not the real one)."
fi
