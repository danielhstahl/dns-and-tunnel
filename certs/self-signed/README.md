# Homelab PKI: step-ca + Caddy + Technitium

## Architecture (no central proxy — each service is independent)

```
                        ┌─────────────────┐
   client devices ───── │   Technitium DNS │  (each hostname -> that
                        └─────────────────┘   service's real IP, directly)

   client ──HTTPS──> NAS (nginx, own cert)
   client ──HTTPS──> LLM server (nginx, own cert)
   client ──HTTPS──> Pi services (nginx, own cert)

                        ┌─────────────────┐
   all services ─────── │     step-ca      │  (private CA, issues certs via ACME)
   request certs from   └─────────────────┘
```

There's no reverse proxy in this variant — every service terminates its own
TLS. DNS points each hostname straight at that service's own IP instead of
at a shared proxy. That trades away Caddy's single-pane-of-glass routing/logs
for one fewer moving part and no proxy-as-single-point-of-failure.

Every service runs its own tiny ACME client, generates its own keypair
**locally**, and only sends the public CSR to step-ca. Private keys never
cross the network. Certs auto-renew on a timer.

## Components in this bundle

| File | Purpose | Runs on |
|---|---|---|
| `01-install-step-ca.sh` | Installs & bootstraps step-ca | your CA host (a Pi is fine) |
| `02-client-renew.sh` | Generic ACME renewal script (edit per host) | every service host |
| `step-cert-renew.service` | systemd unit that runs the renewal script once | every service host |
| `step-cert-renew.timer` | systemd timer, runs the above daily | every service host |
| `nginx-vhost.conf.example` | nginx config using the renewed cert | every service host |
| `technitium-notes.md` | DNS zone notes (direct-to-service, no proxy) | Technitium host |

`Caddyfile.example` from the earlier proxy-based design isn't part of this
variant — nothing sits in front of the services, so there's no proxy config
to write. Each service's own nginx does what Caddy was doing, just for
itself instead of centrally.

## Setup order

1. **Pick an internal domain**, e.g. `home.lab` or `home.yourdomain.internal`.
   Doesn't need to be publicly registered — it's only ever resolved by
   Technitium, never queried on the public internet. (Avoid unregistered
   public-looking TLDs like `.dev` if you're paranoid about collisions —
   `.lab`, `.internal`, `.home.arpa` are safe conventional choices.)
2. **Stand up step-ca** on one host (`01-install-step-ca.sh`). This is your
   root of trust — treat it like you treat Technitium: backed up, ideally on
   a box that's up most of the time, not something you tear down casually.
3. **Trust the root cert once per client device** (laptops, phones, browsers)
   — this is the one manual, one-time step per *device* (not per cert). See
   step 4 in `01-install-step-ca.sh`'s output.
4. **On every service host** (NAS, LLM server, each Pi service), drop
   `02-client-renew.sh` + the two systemd units, edit the three variables at
   the top of the script (`CERT_DOMAIN`, `CA_URL`, `RELOAD_CMD`), enable the
   timer. It'll request a cert immediately and renew automatically from
   then on.
5. **Configure that host's own nginx** using `nginx-vhost.conf.example` as a
   template, pointing at the cert files the renewal script just wrote.
6. **Set up the Technitium zone** per `technitium-notes.md` so each
   hostname resolves directly to that service's own IP.

## Why this is less work than it sounds

- `step-cli` is a single static binary — no package manager fuss.
- The renewal script is ~15 lines; you're copy-pasting the same file to every
  host and changing two variables.
- Cert lifetimes default to 24h in step-ca (configurable) specifically to
  make renewal-automation muscle memory rather than an annual fire drill —
  most people set it to something like 24h–7d with daily renewal checks.
- After initial setup, this requires zero ongoing manual action. Rotation is
  the default behavior, not an event.
