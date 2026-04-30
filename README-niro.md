# inspect — deployment notes

## Pre-deploy: create the config secret

The inspect pod mounts `/config/config.js` from a k8s Secret named `inspect-config`.
Create it once (never commit bot credentials):

```bash
cat > /tmp/inspect-config.js <<'EOF'
module.exports = {
  http: { port: 8080 },
  trust_proxy: false,
  logins: [
    { user: 'BOT1_USERNAME', pass: 'BOT1_PASSWORD', auth: 'BOT1_SHARED_SECRET' },
    { user: 'BOT2_USERNAME', pass: 'BOT2_PASSWORD', auth: 'BOT2_SHARED_SECRET' },
    { user: 'BOT3_USERNAME', pass: 'BOT3_PASSWORD', auth: 'BOT3_SHARED_SECRET' },
  ],
  proxies: [],
  bot_settings: {
    max_attempts: 1,
    request_delay: 1100,
    request_ttl: 3000,
  },
  allowed_origins: ['*'],
  allowed_regex_origins: [],
  rate_limit: { enable: false },
  logLevel: 'info',
  max_simultaneous_requests: 50,
  enable_game_file_updates: false,
  game_files_update_interval: 0,
  database_url: 'postgres://nero:DB_PASS@nero-postgres-service.nero-db.svc.cluster.local:5432/nero?sslmode=disable',
  enable_bulk_inserts: true,
  bulk_key: 'BULK_KEY_RANDOM_STRING',
  max_queue_size: 500,
};
EOF

kubectl create secret generic inspect-config \
  --namespace=personal \
  --from-file=config.js=/tmp/inspect-config.js \
  --dry-run=client -o yaml | kubectl apply -f -

rm /tmp/inspect-config.js
```

Replace placeholders before running:
- `BOT1_USERNAME/PASSWORD/SHARED_SECRET` — Steam account credentials (see below)
- `DB_PASS` — from `kubectl get secret nero -n personal -o jsonpath='{.data.db-pass}' | base64 -d`
- `BULK_KEY_RANDOM_STRING` — `openssl rand -hex 32` (also store in `nero` secret as `inspect-bulk-key`)

## Deploy

```bash
./build.sh
```

## Steam bot provisioning

Create 3-5 fresh Steam accounts:

1. Register at store.steampowered.com (use disposable email per bot)
2. Add funds (≥ $5 minimum spend to remove trade restrictions is NOT needed — inspect is read-only)
3. Enable Steam Mobile Authenticator via the Steam app or SDA (Steam Desktop Authenticator)
4. Capture the `shared_secret` from SDA's `maFiles/<steamid>.maFile`
5. Each bot must own or have played CS2 (free — just launch once)

**Bot rotation**: if a bot gets limited, add a new one to `logins[]` in the secret and rollout restart.

## Verify

```bash
kubectl -n personal port-forward svc/inspect-service 8080:8080
curl http://localhost:8080/stats
# expect: {"bots_online": 3, "queue_size": 0, ...}

# Test an inspect link (get one from Steam market listing page)
curl 'http://localhost:8080/?url=steam%3A%2F%2Frungame%2F730%2F76561202255233023%2F%2B+csgo_econ_action_preview+S...'
# expect: JSON with floatvalue, paintseed, full_item_name, stickers, keychains
```

## Notes

- Replicas must stay at 1 — Steam bots cannot be sharded across pods
- The PVC `inspect-steam-data` persists refresh tokens — avoids Steam Guard prompts on restarts
- The upstream repo (`csfloat/inspect`) has added a deprecation notice but is still functional
- Our fork adds keychain/charm support (commits `497bf1d`, `220f3dd`) not in upstream
