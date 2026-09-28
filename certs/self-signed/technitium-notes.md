# Technitium: internal zone for home.lab

You don't need "split-horizon" in the public-DNS sense here, since `home.lab`
is never registered publicly — Technitium is simply authoritative for it on
your network, full stop.

1. **DNS > Zones > Add Zone**
   - Zone: `home.lab`
   - Type: Primary

2. **Add records** — no central proxy in this variant, so each hostname
   points straight at that service's own real IP:

   | Name | Type | Value |
   |---|---|---|
   | `nas.home.lab` | A | `<nas real ip>` |
   | `llm.home.lab` | A | `<llm server real ip>` |
   | `pi-service.home.lab` | A | `<pi real ip>` |
   | `ca.home.lab` | A | `<step-ca ip>` |

   No wildcard record needed here, since there's no single proxy IP to
   catch-all to — every service gets its own A record when you add it. One
   more line in Technitium each time you stand up a new service, which is a
   fair trade for not running a proxy at all.

3. **Make sure your router/DHCP hands out Technitium as the DNS server**
   for the LAN (you've presumably already done this, just flagging it as a
   dependency of everything above).

4. **No exceptions needed this time** — `ca.home.lab` is just another A
   record like the rest, since nothing is routed through a proxy to begin
   with.
