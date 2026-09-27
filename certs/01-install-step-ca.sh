#!/usr/bin/env bash
# Run this ONCE, on the single host that will act as your private CA.
# A Pi is plenty for this — step-ca is lightweight.
#
# After this script finishes, step-ca runs as a systemd service, listening
# on :443 (or a port of your choice) for ACME requests from every other
# device on your network.

set -euo pipefail

CA_NAME="Homelab CA"
CA_DNS="ca.home.lab"          # <-- change to your CA host's hostname
CA_ADDRESS=":443"             # step-ca's own listen address/port
PROVISIONER_PASSWORD_FILE="/etc/step-ca/password.txt"

echo "==> Installing step-ca and step-cli"
# Debian/Ubuntu/Raspberry Pi OS. For other distros, grab the matching .deb/.rpm
# from https://github.com/smallstep/certificates/releases and
# https://github.com/smallstep/cli/releases instead.
STEP_CLI_VERSION=$(curl -fsSL https://api.github.com/repos/smallstep/cli/releases/latest | grep tag_name | cut -d '"' -f4 | tr -d v)
STEP_CA_VERSION=$(curl -fsSL https://api.github.com/repos/smallstep/certificates/releases/latest | grep tag_name | cut -d '"' -f4 | tr -d v)

ARCH=$(dpkg --print-architecture) # arm64 on a Pi 4/5, amd64 on x86 boxes

curl -fsSLo step-cli.deb \
  "https://github.com/smallstep/cli/releases/download/v${STEP_CLI_VERSION}/step-cli_${STEP_CLI_VERSION}_${ARCH}.deb"
curl -fsSLo step-ca.deb \
  "https://github.com/smallstep/certificates/releases/download/v${STEP_CA_VERSION}/step-ca_${STEP_CA_VERSION}_${ARCH}.deb"

sudo dpkg -i step-cli.deb step-ca.deb
rm step-cli.deb step-ca.deb

echo "==> Bootstrapping the CA (generates root + intermediate keys)"
# You'll be prompted to set a password protecting the CA's private key.
# Store it in a password manager — you need it any time you restart step-ca
# or add provisioners.
step ca init \
  --name "${CA_NAME}" \
  --dns "${CA_DNS}" \
  --address "${CA_ADDRESS}" \
  --provisioner "acme" \
  --acme

echo "==> Adding an ACME provisioner (so clients can request certs without"
echo "    the CA operator manually approving each one)"
step ca provisioner add acme --type ACME

echo "==> Installing step-ca as a systemd service"
sudo mkdir -p /etc/step-ca
sudo cp -r ~/.step/* /etc/step-ca/
sudo tee /etc/systemd/system/step-ca.service > /dev/null <<'EOF'
[Unit]
Description=step-ca private certificate authority
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=step-ca
Environment=STEPPATH=/etc/step-ca
ExecStart=/usr/bin/step-ca /etc/step-ca/config/ca.json --password-file /etc/step-ca/password.txt
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo useradd --system --home /etc/step-ca --shell /usr/sbin/nologin step-ca || true
sudo chown -R step-ca:step-ca /etc/step-ca

echo "==> Save the CA password to ${PROVISIONER_PASSWORD_FILE} (root-readable only)"
echo "    so step-ca can restart unattended, e.g. after a reboot:"
echo "    echo 'yourpasswordhere' | sudo tee ${PROVISIONER_PASSWORD_FILE}"
echo "    sudo chmod 600 ${PROVISIONER_PASSWORD_FILE}"
echo "    sudo chown step-ca:step-ca ${PROVISIONER_PASSWORD_FILE}"

sudo systemctl daemon-reload
sudo systemctl enable --now step-ca

echo ""
echo "======================================================================"
echo " NEXT STEPS"
echo "======================================================================"
echo ""
echo "1. Confirm it's running:"
echo "     sudo systemctl status step-ca"
echo ""
echo "2. Note your CA's ACME directory URL — every client needs this:"
echo "     https://${CA_DNS}${CA_ADDRESS}/acme/acme/directory"
echo ""
echo "3. Grab the root cert fingerprint (needed for client bootstrap):"
echo "     step certificate fingerprint \$(step path)/certs/root_ca.crt"
echo ""
echo "4. ONE-TIME per client device (laptop, phone, browser) — install trust"
echo "   in the OS/browser trust store. On a device with step-cli installed:"
echo "     step ca bootstrap --ca-url https://${CA_DNS}${CA_ADDRESS} \\"
echo "         --fingerprint <fingerprint-from-step-3> --install"
echo "   For phones/devices without step-cli, export the root cert and"
echo "   install it manually (Settings > install certificate), a one-time"
echo "   action per device, same as installing any trusted root."
echo ""
echo "   Root cert to distribute:  \$(step path)/certs/root_ca.crt"
