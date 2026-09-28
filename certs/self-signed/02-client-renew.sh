#!/usr/bin/env bash
# Drop this on EVERY device that terminates its own TLS (NAS, LLM server,
# each Pi service, Caddy itself if you want Caddy to also use step-ca).
#
# Edit the two variables below, then install the systemd service + timer
# (step-cert-renew.service / .timer) alongside it. It requests a cert on
# first run and silently renews when needed on every subsequent run.
#
# Private key is generated locally by step-cli and never leaves this box.

set -euo pipefail

# ---- EDIT THESE TWO ---------------------------------------------------
CERT_DOMAIN="nas.home.lab"                 # this device's hostname
CA_URL="https://ca.home.lab"               # your step-ca host
# -------------------------------------------------------------------

CERT_DIR="/etc/ssl/step"
CERT_FILE="${CERT_DIR}/${CERT_DOMAIN}.crt"
KEY_FILE="${CERT_DIR}/${CERT_DOMAIN}.key"
RELOAD_CMD="systemctl reload nginx"        # change to whatever this service needs

mkdir -p "${CERT_DIR}"

# One-time bootstrap of trust in step-ca, if not already done on this box.
if [ ! -f "$(step path 2>/dev/null)/config/defaults.json" ]; then
  FPRINT="<paste fingerprint from step-ca host here>"
  step ca bootstrap --ca-url "${CA_URL}" --fingerprint "${FPRINT}" --install
fi

if [ ! -f "${CERT_FILE}" ]; then
  echo "==> No existing cert, requesting a new one for ${CERT_DOMAIN}"
  step ca certificate "${CERT_DOMAIN}" "${CERT_FILE}" "${KEY_FILE}" \
    --provisioner acme
else
  echo "==> Checking whether ${CERT_DOMAIN} cert needs renewal"
  # step ca renew exits non-zero (and changes nothing) if renewal isn't due
  # yet, so `|| true` keeps the timer from reporting spurious failures.
  step ca renew --force \
    "${CERT_FILE}" "${KEY_FILE}" \
    && RENEWED=1 || RENEWED=0

  if [ "${RENEWED}" -eq 1 ]; then
    echo "==> Renewed. Reloading service."
    eval "${RELOAD_CMD}"
  else
    echo "==> Not due for renewal yet."
  fi
fi
