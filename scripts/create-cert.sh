#!/bin/bash
# Create a self-signed code signing certificate in the login keychain. Signing
# with the same certificate on every build keeps the Accessibility permission.
set -euo pipefail

name="$1"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
umask 077

# /usr/bin/openssl is LibreSSL, whose PKCS#12 files the keychain can import.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days 3650 \
  -subj "/CN=$name" \
  -addext "extendedKeyUsage=critical,codeSigning" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "basicConstraints=critical,CA:false" \
  -keyout "$dir/key.pem" -out "$dir/cert.pem" 2>/dev/null
/usr/bin/openssl pkcs12 -export -name "$name" -passout pass:import \
  -inkey "$dir/key.pem" -in "$dir/cert.pem" -out "$dir/cert.p12"
security import "$dir/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
  -P import -T /usr/bin/codesign
echo "Created the code signing certificate $name"
