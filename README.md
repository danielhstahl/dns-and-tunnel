## Home networking configuration

### DNS

I use [technitium](https://technitium.com/dns/) for self-hosted DNS.  It manages my internal DNS and blocks ads. Technitium runs on Docker on my NAS (Synology).

### Tunneling

To access intranet on my phone, I use [tailscale](https://tailscale.com/).  Tailscale runs as a service on my NAS (Synology, native app).  

### Notification

I run a self-hosted [ntfy](https://ntfy.sh/) service.  This runs as a docker on my NAS (Synology). See [docker-compose](docker-compose.yml) for the definition. 

To access on Android, use the Tailscale base-url (same as in [server.yml](server.yml)) with the ntfy port (here, 6001).
