# Deploying the LMS Prototype

The prototype is a Vite SPA that builds to static files and is served by Caddy on the VPS.

**Live URL**: https://lms-prototype.mereka.dev

---

## Auto-Deploy (Recommended)

Push changes to `frontend/` on `main` and it deploys automatically via GitHub Actions.

```bash
git add -A && git commit -m "update prototype" && git push
```

Check deploy status: https://github.com/Biji-Biji-Initiative/mereka-lms-prototype/actions

You can also trigger a deploy manually from the Actions tab ("Run workflow" button).

**Important**: Do not force-push to `main` -- it will wipe the workflow file and other docs. Use normal pushes.

---

## Manual Deploy

If you need to deploy without pushing (e.g. testing locally first):

**Prerequisites**: Node.js 20+, Tailscale connected (see [First-Time Setup](#first-time-setup-tailscale--for-manual-deploy-only) below)

```bash
cd frontend && npm install && npm run build
rsync -avz --delete dist/ root@g-mereka-vps:/home/gurpreet/projects/standalone/lms-prototype/dist/
```

Changes are live immediately — no server restart needed.

---

## First-Time Setup (Tailscale — for manual deploy only)

Auto-deploy doesn't need Tailscale. But if you want to deploy manually or SSH into the VPS:

### 1. Get invited to the tailnet

Ask Miranda or Gurpreet to invite your email at https://login.tailscale.com/admin/users.

### 2. Install Tailscale

Download from https://tailscale.com/download and sign in with your invited email.

### 3. Verify connection

```bash
tailscale status | grep mereka-vps
ssh root@g-mereka-vps "echo connected"
```

If SSH is denied, ask Miranda or Gurpreet to update the ACL at https://login.tailscale.com/admin/acls.

---

## Local Development

```bash
cd frontend
npm install
npm run dev
```

Opens at http://localhost:5173 with hot reload.

### Environment Variables

Set in `.env` or as shell exports before building:

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_OPENEDX_BASE_URL` | `""` (empty) | Open edX LMS API base. Empty = same origin (uses proxy) |
| `VITE_OPENEDX_AUTHN_URL` | `https://apps.academyv2.mereka.dev` | Authn MFE URL |
| `VITE_OPENEDX_STUDIO_URL` | `https://studio.academyv2.mereka.dev` | Studio URL |
| `VITE_USE_MOCK_DATA` | `false` | Use mock data instead of real API |
| `VITE_SHOW_CROSS_DOMAIN_AUTH_NOTICE` | `true` | Show auth notice banner |

---

## Infrastructure Details

| Component | Detail |
|-----------|--------|
| Server | `g-mereka-vps` (Tailscale: `100.67.248.45`) |
| Files | `/home/gurpreet/projects/standalone/lms-prototype/dist/` |
| Web server | Caddy (static `file_server`, no process manager) |
| Domain | `lms-prototype.mereka.dev` |
| SSL | Cloudflare edge via `*.mereka.dev` wildcard tunnel |
| Caddy config | `/home/gurpreet/projects/vps/infrastructure/caddy/Caddyfile` |

### Caddy Route

```caddyfile
http://lms-prototype.mereka.dev {
    root * /home/gurpreet/projects/standalone/lms-prototype/dist
    file_server
    encode zstd gzip
    try_files {path} /index.html
}
```

---

## Troubleshooting

### Can't SSH to VPS

Make sure Tailscale is running:

```bash
tailscale status | grep mereka-vps
```

If you see the VPS but SSH is denied, your user needs SSH access in the tailnet ACL. Ask Miranda or Gurpreet.

### Site returns 502

Caddy is down:

```bash
ssh root@g-mereka-vps "systemctl status caddy --no-pager"
```

### Site returns 404 for routes like /dashboard

The `try_files` rule may be missing. Check the Caddyfile has `try_files {path} /index.html` in the `lms-prototype.mereka.dev` block.

### Changes not showing after deploy

Browser cache. Hard refresh with `Cmd+Shift+R` or open in incognito. Vite hashes asset filenames so normally cache busting is automatic.

### Build fails

```bash
cd frontend
rm -rf node_modules dist
npm install
npm run build
```

---

## Netlify (Backup)

The repo is also configured for Netlify at `mereka-lms-proto.netlify.app`. Netlify builds automatically on push to `main`. See `netlify.toml` for config. The VPS at `lms-prototype.mereka.dev` is the primary deployment.
