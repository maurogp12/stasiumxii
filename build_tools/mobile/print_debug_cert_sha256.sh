#!/usr/bin/env bash
# Print the SHA-256 of the shared STASIUM XII mobile debug certificate.
# One lowercase hex line, no colons. Same digest as `keytool -list -v` SHA256.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
keystore="${here}/stasiumxii-mobile-debug.keystore"
alias_name="stasiumxii_mobile_debug"
storepass="stasiumxii-mobile-debug"

keytool -exportcert \
	-alias "${alias_name}" \
	-keystore "${keystore}" \
	-storepass "${storepass}" \
	| openssl x509 -inform DER -noout -fingerprint -sha256 \
	| sed 's/^.*=//;s/://g' \
	| tr 'A-F' 'a-f'
