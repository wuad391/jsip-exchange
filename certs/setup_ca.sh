#!/usr/bin/env bash
# One-time setup: a self-signed CA, plus a server cert signed by it.
#
# The CA and the server are the same trust boundary here (whoever runs this
# script controls both), so unlike participant onboarding there's no
# "private key never leaves the owner's machine" property worth
# demonstrating by splitting this into two steps.
set -euo pipefail
cd "$(dirname "$0")"

if [[ -f ca.key && -f ca.crt ]]; then
  echo "CA already exists (ca.key, ca.crt) -- skipping."
else
  openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
    -keyout ca.key -out ca.crt \
    -subj "/CN=JSIP Exchange Test CA"
  echo "Created CA: ca.key, ca.crt"
fi

if [[ -f server.key && -f server.crt ]]; then
  echo "Server cert already exists (server.key, server.crt) -- skipping."
else
  openssl req -newkey rsa:2048 -sha256 -nodes \
    -keyout server.key -out server.csr \
    -subj "/CN=localhost"
  openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days 3650 -sha256
  rm -f server.csr
  echo "Created server cert: server.key, server.crt"
fi
