# Technitium: internal resolution for home.yourdomain.com

Your domain (`yourdomain.com`) is real and publicly registered, but
`home.yourdomain.com` only needs to resolve *inside* your LAN — you don't
need to (and shouldn't) publish these private IPs in public DNS.

1. **DNS > Zones > Add Zone**
   - Zone: `home.yourdomain.com`
   - Type: Primary
   - This makes Technitium authoritative for this subdomain *on your
     network only* — it has no effect on public DNS, which is fine, since
     DNS-01 challenges use a separate TXT record on the parent zone at
     your public DNS provider (Cloudflare), not this internal zone at all.

2. **Add A records** — each hostname points straight at that service's own
   real IP:

   | Name | Type | Value |
   |---|---|---|
   | `nas.home.yourdomain.com` | A | `<nas real ip>` |
   | `llm.home.yourdomain.com` | A | `<llm server real ip>` |
   | `pi-service.home.yourdomain.com` | A | `<pi real ip>` |

3. **Make sure your router/DHCP hands out Technitium as the DNS server**
   for the LAN.

4. **Nothing to configure on Cloudflare's DNS records themselves** beyond
   the API token — acme.sh creates and deletes its own `_acme-challenge`
   TXT records automatically during each issuance, and Technitium never
   needs to know about them.
