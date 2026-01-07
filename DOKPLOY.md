# Dokploy Deployment Guide

This documents the setup for deploying Phoenix/Elixir apps on Dokploy with preview deployments.

## Server Setup

**Server**: `91.98.72.126` (Hetzner)
**Domain**: `perfux.dev`
**Dokploy Dashboard**: https://perfux.dev

## Issues & Solutions

### 1. Firewall: ufw-docker breaks on container restart

**Problem**: `ufw-docker` creates IP-based rules. When containers restart, they get new IPs → rules break → site goes down.

**Solution**: Use port-based iptables rules instead:
```bash
# Remove ufw-docker, use iptables-persistent
sudo apt remove ufw
sudo apt install iptables-persistent

# Add permanent port-based rules
sudo iptables -I DOCKER-USER -p tcp --dport 80 -j ACCEPT
sudo iptables -I DOCKER-USER -p tcp --dport 443 -j ACCEPT
sudo netfilter-persistent save
```

### 2. Docker network pool conflict

**Problem**: `Pool overlaps with other one on this address space` - Docker's default 10.0.0.0/24 conflicts with existing networks.

**Solution**: Change Docker's address pools in `/etc/docker/daemon.json`:
```json
{
  "default-address-pools": [
    {"base":"172.20.0.0/16","size":24},
    {"base":"172.21.0.0/16","size":24}
  ]
}
```
Then: `sudo systemctl restart docker`

### 3. Preview deployments: wildcard domain format

**Problem**: `Error: The base domain must start with "*."`

**Solution**: Set `previewWildcard` to `*.preview.perfux.dev` (not `preview.perfux.dev`).

### 4. Preview deployments: port conflict

**Problem**: `port '4000' is already in use by service` - Main app publishes port 4000 in ingress mode, conflicts with previews.

**Solution**: Remove port mapping from main app. Traefik handles routing via domains - no need to publish ports.

### 5. Preview deployments: missing env vars

**Problem**: `environment variable SECRET_KEY_BASE is missing` - Previews don't inherit main app's env vars.

**Solution**: Set `previewEnv` on the application with required env vars:
```
SECRET_KEY_BASE=<generated>
DATABASE_PATH=/data/phoenix.db
```

### 6. Wildcard SSL certificates

**Problem**: Let's Encrypt HTTP-01 can't issue wildcard certs. Need DNS-01 challenge.

**Solution**:
1. Add Cloudflare API token to Traefik env: `CF_DNS_API_TOKEN=xxx`
2. Add `cloudflare` certResolver to traefik.yml:
```yaml
certificatesResolvers:
  cloudflare:
    acme:
      email: your@email.com
      storage: /etc/dokploy/traefik/dynamic/acme-cf.json
      dnsChallenge:
        provider: cloudflare
        resolvers:
          - "1.1.1.1:53"
          - "1.0.0.1:53"
```
3. Set `previewCustomCertResolver: "cloudflare"` on apps

## App Configuration

### Main App Settings
- **sourceType**: `github`
- **Domain**: `phoenix.perfux.dev`
- **Container port**: 4000
- **No port publishing** (Traefik routes via domain)

### Environment Variables (main app)
```
SECRET_KEY_BASE=<64-byte-hex>
PHX_HOST=phoenix.perfux.dev
DATABASE_PATH=/data/phoenix.db
```

### Preview Settings
- **previewWildcard**: `*.preview.perfux.dev`
- **previewPort**: 4000
- **previewHttps**: true
- **previewCustomCertResolver**: `cloudflare`
- **previewEnv**: Same as main app (SECRET_KEY_BASE, DATABASE_PATH)

### Persistent Storage
- **Host path**: `/data/phoenix-sqlite`
- **Container path**: `/data`

## DNS Setup (Cloudflare)

```
perfux.dev        A     91.98.72.126
*.perfux.dev      A     91.98.72.126
```

The wildcard covers all subdomains including `*.preview.perfux.dev`.

## API Examples

### Deploy app
```bash
curl -X POST "https://perfux.dev/api/trpc/application.deploy" \
  -H "x-api-key: $TOKEN" \
  -d '{"json":{"applicationId":"xxx"}}'
```

### Update preview settings
```bash
curl -X POST "https://perfux.dev/api/trpc/application.update" \
  -H "x-api-key: $TOKEN" \
  -d '{"json":{
    "applicationId":"xxx",
    "previewWildcard":"*.preview.perfux.dev",
    "previewCustomCertResolver":"cloudflare",
    "previewHttps":true
  }}'
```

### List preview deployments
```bash
curl "https://perfux.dev/api/trpc/previewDeployment.all?input={\"json\":{\"applicationId\":\"xxx\"}}" \
  -H "x-api-key: $TOKEN"
```

## Scaling to New Projects

For each new project:
1. Create app in Dokploy
2. Connect GitHub repo via existing GitHub App
3. Set `previewCustomCertResolver: "cloudflare"`
4. Set `previewWildcard: "*.preview.perfux.dev"`
5. Set `previewEnv` with required env vars
6. No DNS changes needed (wildcard covers all)
