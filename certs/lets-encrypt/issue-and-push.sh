#!/usr/bin/env bash
# Run on the ONE central host that holds the Cloudflare API token.
# Reads hosts.conf, and for each line: issues/renews a cert via DNS-01,
# pushes the cert+key to that host over SSH, triggers a reload.
#
# Safe to run daily via the systemd timer — acme.sh only actually renews
# when a cert is within ~30 days of expiry; otherwise this is a no-op.

set -euo pipefail

# ---- Cloudflare API token ----------------------------------------------
# Create at: dash.cloudflare.com > My Profile > API Tokens > Create Token
# Scope: Zone:DNS:Edit, restricted to your one zone.
# acme.sh's Cloudflare DNS hook (dns_cf) reads these two env vars:
export CF_Token="your-cloudflare-api-token-here"
export CF_Account_ID="your-cloudflare-account-id-here"
# -------------------------------------------------------------------

HOSTS_FILE="$(dirname "$0")/hosts.conf"
STAGE_DIR="/tmp/cert-stage"
ACME_SH="${HOME}/.acme.sh/acme.sh"

mkdir -p "${STAGE_DIR}"

# Skip blank lines and comments in hosts.conf
grep -Ev '^\s*(#|$)' "${HOSTS_FILE}" | while IFS='|' read -r RAW_HOST RAW_TARGET RAW_RELOAD; do
  HOSTNAME=$(echo "${RAW_HOST}" | xargs)
  SSH_TARGET=$(echo "${RAW_TARGET}" | xargs)
  RELOAD_CMD=$(echo "${RAW_RELOAD}" | xargs)

  echo "=================================================================="
  echo "==> ${HOSTNAME}"
  echo "=================================================================="

  # Issue (or, on later runs, check/renew) via DNS-01 against Cloudflare.
  # --force isn't used here on purpose: acme.sh's own renewal-window logic
  # decides whether to actually re-issue, so this is safe to run daily.
  "${ACME_SH}" --issue --dns dns_cf -d "${HOSTNAME}" \
    --cert-home "${STAGE_DIR}" || true

  CERT_FILE="${STAGE_DIR}/${HOSTNAME}/${HOSTNAME}.cer"
  KEY_FILE="${STAGE_DIR}/${HOSTNAME}/${HOSTNAME}.key"
  FULLCHAIN_FILE="${STAGE_DIR}/${HOSTNAME}/fullchain.cer"

  if [ ! -f "${FULLCHAIN_FILE}" ] || [ ! -f "${KEY_FILE}" ]; then
    echo "!! No cert files found for ${HOSTNAME}, skipping push."
    continue
  fi

  echo "==> Pushing to ${SSH_TARGET}"
  ssh "${SSH_TARGET}" "sudo mkdir -p /etc/ssl/le && sudo chown \$(whoami) /etc/ssl/le"
  scp "${FULLCHAIN_FILE}" "${SSH_TARGET}:/etc/ssl/le/${HOSTNAME}.crt"
  scp "${KEY_FILE}"       "${SSH_TARGET}:/etc/ssl/le/${HOSTNAME}.key"
  ssh "${SSH_TARGET}" "sudo chmod 600 /etc/ssl/le/${HOSTNAME}.key"

  echo "==> Reloading remote service"
  ssh "${SSH_TARGET}" "${RELOAD_CMD}"

  echo "==> Done: ${HOSTNAME}"
done

echo "=================================================================="
echo "All hosts processed."
