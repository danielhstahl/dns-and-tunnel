# Homelab TLS: Let's Encrypt (DNS-01) + individual per-host certs

## Architecture

```
                        ┌─────────────────┐
   client devices ───── │   Technitium DNS │  (each hostname -> that
                        └─────────────────┘   service's real IP, directly)

   client ──HTTPS──> NAS (nginx, own LE cert, own key)
   client ──HTTPS──> LLM server (nginx, own LE cert, own key)
   client ──HTTPS──> Pi services (nginx, own LE cert, own key)

                        ┌───────────────────────┐
   one central host ──  │ acme.sh + Cloudflare   │  issues a SEPARATE cert
   issues + pushes      │ API token (DNS-01)     │  per hostname, pushes
                        └───────────────────────┘  each to its own server
```

No private CA to run, no root cert to install on any client device —
Let's Encrypt is already trusted everywhere. One central host does all the
issuing (it's the only thing that needs your DNS provider's API token) and
pushes each cert to its owning server over SSH. Every server gets its own
unique keypair; a compromise of one server never exposes another's identity,
unlike a shared wildcard cert.

## Prerequisites

- A real domain you control, with DNS hosted somewhere with an API
  (Cloudflare's free tier is what these scripts assume).
- A Cloudflare **API token** (not your global key) scoped to
  `Zone:DNS:Edit` for just that one zone. Create it at
  `dash.cloudflare.com > My Profile > API Tokens > Create Token`.
- SSH key-based access from the central host to every server that gets a
  cert (no passwords — the push script needs to run unattended).

## Components in this bundle

| File | Purpose | Runs on |
|---|---|---|
| `hosts.conf` | List of hostnames to issue certs for + push targets | central host |
| `issue-and-push.sh` | Requests each cert via DNS-01, pushes it, reloads remote nginx | central host |
| `le-renew.service` / `le-renew.timer` | systemd units to run the script on a schedule | central host |
| `nginx-vhost.conf.example` | nginx config pointing at the pushed cert | every service host |
| `technitium-notes.md` | DNS zone notes (direct-to-service) | Technitium host |

## Setup order

1. **Install acme.sh** on the one central host (doesn't need to be
   powerful — a Pi is fine): `curl https://get.acme.sh | sh`
2. **Set your Cloudflare API token** as an environment variable on that host
   (see comments in `issue-and-push.sh`).
3. **Generate an SSH keypair** for the central host (if it doesn't have one)
   and copy its public key to every server's `authorized_keys` for a
   dedicated deploy user — don't reuse your personal login for this.
4. **Fill in `hosts.conf`** — one line per hostname/server.
5. **Run `issue-and-push.sh` once manually** to confirm it works end to end,
   then install the systemd timer so it checks/renews automatically
   (acme.sh only actually re-issues when a cert is within its renewal
   window, so running it daily is safe and normal).
6. **Configure each server's nginx** per `nginx-vhost.conf.example`.
7. **Set up Technitium** per `technitium-notes.md`.

## Why per-host instead of one wildcard

A wildcard (`*.home.yourdomain.com`) is one cert/key shared identically
across every server — simpler to distribute, but a single compromised
server leaks a key that's valid for *every* hostname. Individual certs cost
a few more lines in the issuance script (looping over hostnames instead of
requesting one `*`) but mean each server's blast radius is itself alone.
Given you're treating "assume the LAN can be sniffed / a device can be
compromised" as a real design constraint, this is the version worth running.
