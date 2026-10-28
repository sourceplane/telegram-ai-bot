#!/usr/bin/env bash
# THE REBRAND WRITES EACH VALUE ONCE, AND WHAT IT WROTE STAYS WRITTEN.
#
# Drives the real tooling/rebrand/rebrand.mjs over one-file trees and compares
# the file. Each case is a shape this baseline's identity actually takes in the
# tree — the source link, the bot-name seam, the worker name in the component
# and the wrangler config, the KV namespace titles and the terraform `repo`
# they are built from, the placeholder domain, a secret ref — and the
# survival cases run through three passes, so a value an earlier rebrand
# wrote (a re-run phase re-runs the rebrand over everything placed) comes
# out of every later one unchanged.
#
# The identity is PINNED (fixtures/baseline-identity.telegram-ai-bot.json)
# rather than read from .baseline/identity.json: what this tests is the engine,
# and its fixtures spell the identity out literally.
#
# Needs: node, git. No network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
rebrand="$here/../tooling/rebrand/rebrand.mjs"
identity="$here/fixtures/baseline-identity.telegram-ai-bot.json"

fail=0
# check NAME VALUES-JSON FILE CONTENT WANT [PASSES]
check() {
  local name="$1" values="$2" file="$3" content="$4" want="$5" passes="${6:-1}"
  local tmp got out i
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  for ((i = 1; i <= passes; i++)); do
    git -C "$tmp" add -A
    if ! out="$(cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty 2>&1)"; then
      echo "   ✕  $name: rebrand pass $i failed:" >&2
      printf '%s\n' "$out" | sed 's/^/        /' >&2
      fail=1
      rm -rf "$tmp"
      return
    fi
  done
  got="$(cat "$tmp/$file")"
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then
    echo "   ok  $name"
  else
    echo "   ✕  $name:" >&2
    echo "        got:  $got" >&2
    echo "        want: $want" >&2
    fail=1
  fi
}

acme='{"reponame":"acme-views","productname":"Acme Views","productdomain":"acme.dev","githuborg":"acme-inc","subdomain":"acme","orunWorkspace":"ws_79BDXAZQ"}'

echo "── rebrand: the bot's own identity"
check "the source link names the product's owner and repository" \
  "$acme" apps/bot/src/identity.ts \
  'export const SOURCE_URL = "https://github.com/sourceplane/telegram-ai-bot"' \
  'export const SOURCE_URL = "https://github.com/acme-inc/acme-views"'
check "the bot-name seam takes the product's name" \
  "$acme" apps/bot/src/identity.ts 'export const BOT_NAME = "AI Telegram Bot"' \
  'export const BOT_NAME = "Acme Views"'
check "…and stays a valid string for a name with an apostrophe and an ampersand" \
  '{"reponame":"sams-views","productname":"Sam'"'"'s Views & Counts","productdomain":"sam.dev"}' \
  apps/bot/src/identity.ts 'export const BOT_NAME = "AI Telegram Bot"' \
  'export const BOT_NAME = "Sam'"'"'s Views & Counts"'
check "the display name elsewhere is content, and is left alone" \
  "$acme" apps/bot/README.md 'An AI Telegram Bot on Workers, the AI Telegram Bot.' \
  'An AI Telegram Bot on Workers, the AI Telegram Bot.'
check "the worker URL in the smoke is re-prefixed, the environment suffix kept" \
  "$acme" apps/bot/component.yaml '    smokeCommand: base="${DEPLOYED_URL:-https://telegram-ai-bot-bot-${ORUN_ENVIRONMENT}.your-workers-subdomain.workers.dev}"' \
  '    smokeCommand: base="${DEPLOYED_URL:-https://acme-views-bot-${ORUN_ENVIRONMENT}.acme.workers.dev}"'
check "the wrangler config's worker name, template and render alike" \
  "$acme" apps/bot/wrangler.template.jsonc '  "name": "telegram-ai-bot-bot",' \
  '  "name": "acme-views-bot",'
check "the environment URLs: worker name and subdomain" \
  "$acme" intent.yaml '    url: https://telegram-ai-bot-bot-stage.your-workers-subdomain.workers.dev' \
  '    url: https://acme-views-bot-stage.acme.workers.dev'
check "the KV namespace's terraform repo — every namespace title is built on it" \
  "$acme" infra/terraform/cloudflare-kv/terraform/main.tf '  default = "telegram-ai-bot"' \
  '  default = "acme-views"'
check "the per-environment terraform repo parameter" \
  "$acme" intent.yaml '        repo: telegram-ai-bot' \
  '        repo: acme-views'
check "a fixture's namespace title follows the same rule" \
  "$acme" apps/bot/wiring.fixture.json '    "app_kv_title": "stg-telegram-ai-bot-app-kv-stage"' \
  '    "app_kv_title": "stg-acme-views-app-kv-stage"'
check "the placeholder domain is the product's domain, not a renamed slug" \
  "$acme" intent.yaml '      BASE_DOMAIN: telegram-ai-bot.example.com' \
  '      BASE_DOMAIN: acme.dev'
check "no domain given: the reserved placeholder, for an owner to replace later" \
  '{"reponame":"acme-views","productname":"Acme Views","githuborg":"acme-inc","subdomain":"acme"}' \
  intent.yaml '      BASE_DOMAIN: telegram-ai-bot.example.com' \
  '      BASE_DOMAIN: acme-views.example.com'
check "an empty domain is no domain" \
  '{"reponame":"acme-views","productname":"Acme Views","productdomain":""}' \
  intent.yaml '      BASE_DOMAIN: telegram-ai-bot.example.com' \
  '      BASE_DOMAIN: acme-views.example.com'
check "the repo slug" \
  "$acme" package.json '  "name": "telegram-ai-bot",' \
  '  "name": "acme-views",'
check "a wiring secret ref names the product's workspace and project" \
  "$acme" apps/bot/component.yaml \
  '    WIRING_CLOUDFLARE_KV_STAGE: "secret://telegram-ai-bot/telegram-ai-bot/stage/WIRING_CLOUDFLARE_KV"' \
  '    WIRING_CLOUDFLARE_KV_STAGE: "secret://ws_79BDXAZQ/acme-views/stage/WIRING_CLOUDFLARE_KV"'
check "an optional bot secret ref too" \
  "$acme" apps/bot/component.yaml \
  '    TELEGRAM_TOKEN: "secret://telegram-ai-bot/telegram-ai-bot/{{ .environment }}/TELEGRAM_TOKEN"' \
  '    TELEGRAM_TOKEN: "secret://ws_79BDXAZQ/acme-views/{{ .environment }}/TELEGRAM_TOKEN"'
check "a templated provider secret ref too" \
  "$acme" infra/terraform/cloudflare-kv/component.yaml \
  '    CLOUDFLARE_API_TOKEN: "secret://telegram-ai-bot/telegram-ai-bot/{{ .environment }}/CLOUDFLARE_API_TOKEN"' \
  '    CLOUDFLARE_API_TOKEN: "secret://ws_79BDXAZQ/acme-views/{{ .environment }}/CLOUDFLARE_API_TOKEN"'
check "org-owned identity is not renamed" \
  "$acme" intent.yaml 'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai' \
  'apiVersion: sourceplane.io/v1 # mail ops@sourceplane.ai'
check "without githuborg the source link keeps the baseline's owner" \
  '{"reponame":"acme-views","productname":"Acme Views","productdomain":"acme.dev"}' \
  apps/bot/src/identity.ts 'const SOURCE_URL = "https://github.com/sourceplane/telegram-ai-bot"' \
  'const SOURCE_URL = "https://github.com/sourceplane/acme-views"'

echo "── rebrand: a written value is not rewritten, in any later pass"
contains='{"reponame":"telegram-ai-bot-2","productname":"AI Telegram Bot 2","productdomain":"telegram-ai-bot.example.com.au","githuborg":"sourceplane","subdomain":"your-workers-subdomain-2"}'
check "a repo slug containing the baseline's slug survives three passes" \
  "$contains" package.json '  "name": "telegram-ai-bot",' \
  '  "name": "telegram-ai-bot-2",' 3
check "a worker name built on it survives three passes" \
  "$contains" apps/bot/wrangler.template.jsonc '  "name": "telegram-ai-bot-bot",' \
  '  "name": "telegram-ai-bot-2-bot",' 3
check "a namespace title built on it survives three passes" \
  "$contains" apps/bot/wiring.fixture.json '"app_kv_title": "prod-telegram-ai-bot-app-kv-prod"' \
  '"app_kv_title": "prod-telegram-ai-bot-2-app-kv-prod"' 3
check "a domain containing the baseline's domain survives three passes" \
  "$contains" intent.yaml 'BASE_DOMAIN: telegram-ai-bot.example.com' \
  'BASE_DOMAIN: telegram-ai-bot.example.com.au' 3
check "a subdomain containing the placeholder survives three passes" \
  "$contains" intent.yaml '    url: https://telegram-ai-bot-bot-prod.your-workers-subdomain.workers.dev' \
  '    url: https://telegram-ai-bot-2-bot-prod.your-workers-subdomain-2.workers.dev' 3
check "a bot name containing the baseline's name survives three passes" \
  "$contains" apps/bot/src/identity.ts 'export const BOT_NAME = "AI Telegram Bot"' \
  'export const BOT_NAME = "AI Telegram Bot 2"' 3

# --verify runs in every phase. Without the product's values it cannot tell
# the product's own identity from a leftover; with them it can. A real
# leftover must fail it either way.
verify() { # NAME VALUES FILE CONTENT WANT(pass|fail) [--values]
  local name="$1" values="$2" file="$3" content="$4" want="$5" withvalues="${6:-}" tmp got
  tmp="$(mktemp -d)"
  git -C "$tmp" init -q
  mkdir -p "$tmp/$(dirname "$file")" "$tmp/.rebrand"
  printf '%s\n' "$content" > "$tmp/$file"
  printf '%s\n' "$values" > "$tmp/.rebrand/values.json"
  git -C "$tmp" add -A
  if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --verify ${withvalues:+--values .rebrand/values.json} >/dev/null 2>&1); then got=pass; else got=fail; fi
  rm -rf "$tmp"
  if [ "$got" = "$want" ]; then echo "   ok  $name"; else echo "   ✕  $name: --verify ${got}ed, want $want" >&2; fail=1; fi
}
echo "── rebrand --verify: the product's own identity is not residue"
verify "given the values, a slug containing the baseline's passes" \
  "$contains" package.json '"name": "telegram-ai-bot-2"' pass --values
verify "without them it cannot know, and fails" \
  "$contains" package.json '"name": "telegram-ai-bot-2"' fail
verify "given the values, a real leftover still fails" \
  "$acme" package.json '"name": "telegram-ai-bot"' fail --values
verify "a leftover worker name fails" \
  "$acme" apps/bot/wrangler.jsonc '"name": "telegram-ai-bot-bot",' fail --values
verify "a leftover namespace title fails" \
  "$acme" apps/bot/wiring.fixture.json '"app_kv_title": "stg-telegram-ai-bot-app-kv-stage"' fail --values
verify "a leftover code identifier fails (no rule renames it — so nothing may spell it)" \
  "$acme" apps/bot/src/x.ts 'export class TelegramAiBot {}' fail --values
verify "a clean product passes" \
  "$acme" package.json '"name": "acme-views"' pass --values

echo "── rebrand: a residue it cannot rename fails the rebrand itself"
tmp="$(mktemp -d)"; git -C "$tmp" init -q; mkdir -p "$tmp/.rebrand" "$tmp/apps/bot"
printf '%s\n' "$acme" > "$tmp/.rebrand/values.json"
printf 'const x = "TELEGRAM_AI_BOT_TOKEN"\n' > "$tmp/apps/bot/x.ts"
git -C "$tmp" add -A
if (cd "$tmp" && node "$rebrand" --baseline-identity "$identity" --values .rebrand/values.json --allow-dirty >/dev/null 2>&1); then
  echo "   ✕  an unrenamable env-var prefix passed the rebrand" >&2; fail=1
else
  echo "   ok  an unrenamable env-var prefix fails the rebrand, naming the file"
fi
rm -rf "$tmp"

[ "$fail" -eq 0 ] || exit 1
echo "rebrand.test.sh: ok"
