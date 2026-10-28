#!/usr/bin/env bash
# TIER 2 — the bot a bootstrap produces builds, deploys (dry), serves, binds
# its webhook and answers.
#
# placement.test.sh proves the tree a bootstrap ends with is the right tree.
# This proves it WORKS, by doing to it what its own pipelines will:
#
#   1. at the 01-product landing (the commit its one pull request merges),
#      the landing's own checks — install with the lockfile the bot ships,
#      render the fixture and check the committed config IS that render,
#      typecheck, lint, test (every upstream library's tests and the
#      Worker's, in workerd), build. The landing is checked in the box with
#      `orun validate` and `orun plan` alone (`checks: local`; its PR's CI on
#      an `orun/BASE-…` branch is `plan` alone), so THIS is where the lint
#      and the tests run over a bootstrapped bot: before the tag;
#   2. the stage lane's own steps, read out of `orun plan` in the product for a
#      pull request — EVERY `run:` step of the job, in order, exactly as
#      planned: the install, `verify-worker-structure` (the committed
#      `wrangler.jsonc`, checked BEFORE any build), the build (the live
#      wiring render from the stage document, then the libraries and the
#      bundle with its guard), the typecheck and `deploy-dry-run`
#      (`wrangler deploy --dry-run --env stage`) — IN THE TREE THE RUNNER
#      STAGES for the job (testing/lib/stage-job.py), with the job's secrets
#      in its environment as the platform resolves them: the namespace id in
#      the built config and the dry run's binding asserted to be the stage
#      document's, not the fixture's;
#   3. serve the built Worker with `wrangler dev --env stage` (a local KV
#      behind DATABASE; `--local`, since Workers AI is remote-only) and run
#      the deploy profile's planned `smoke` step against it, retry loop and
#      all — with NO bot token, as a fresh product deploys: the webhook
#      binding is a named no-op, `/health` reads the namespace and says to
#      connect a token, the pages carry the product's name;
#   4. then WITH a token, as the deploy's secrets push leaves the Worker (the
#      same secrets in `.dev.vars`): the admin signs in with its password and
#      points the bot at a stand-in Telegram API (testing/lib/telegram-api.py,
#      which refuses every token but the bot's) and adds a stand-in
#      OpenAI-compatible provider (testing/lib/model-api.py) through the
#      admin page's own RPC; the planned smoke step binds the webhook — the
#      stand-in receives setWebhook at the Worker's own URL, the commands and
#      the menu button — and an update posted to the webhook is answered: the
#      model is asked the user's message and its reply is sent to the chat.
#
# What it cannot do is the platform's half: create the repository, mint the
# brokered Cloudflare token, apply the namespace, deploy, push the secrets
# for real, probe workers.dev — nor reach Telegram or Workers AI themselves.
# The KV root is verified to `terraform validate` and its plan is part of
# every pull request's lanes.
#
# Needs: orun, node, pnpm, python3 (+PyYAML), git, curl, setsid, and the
# network for `pnpm install` (or a warm store). A few minutes: two installs.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=lib/bootstrap.sh
source "$here/lib/bootstrap.sh"

for bin in orun node pnpm python3 git curl setsid; do
  command -v "$bin" >/dev/null || { echo "e2e.test.sh needs $bin on PATH" >&2; exit 1; }
done

scratch="$(mktemp -d)"
pids=()
# wrangler dev runs under pnpm, node and workerd processes; a TERM to the
# first does not reach the rest, and waiting on it then never returns. So
# every server is started as its own process group (setsid) and the whole
# group is stopped.
stop_group() {
  kill -TERM -- "-$1" 2>/dev/null || true
  for _ in 1 2 3 4 5 6 7 8 9 10; do kill -0 -- "-$1" 2>/dev/null || break; sleep 0.5; done
  kill -KILL -- "-$1" 2>/dev/null || true
}
cleanup() {
  for p in "${pids[@]}"; do stop_group "$p"; done
  rm -rf "$scratch"
}
trap cleanup EXIT
values="$here/fixtures/acme.json"
repo="$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['reponame'])" "$values")"
export CI=1 WRANGLER_SEND_METRICS=false TURBO_TELEMETRY_DISABLED=1
free_port() { python3 -c "import socket;s=socket.socket();s.bind(('127.0.0.1',0));print(s.getsockname()[1]);s.close()"; }

LANDING_CHECKS=(
  "pnpm install --frozen-lockfile"
  "pnpm run wire:fixture"
  "git diff --exit-code"
  "pnpm typecheck"
  "pnpm lint"
  "pnpm test"
  "pnpm build"
)
checks() { # DIR LOG
  local dir="$1" log="$2" cmd
  for cmd in "${LANDING_CHECKS[@]}"; do
    echo "   \$ $cmd" | tee -a "$log"
    if ! (cd "$dir" && bash -c "$cmd") >> "$log" 2>&1; then
      echo "FAIL: \`$cmd\` failed in $dir" >&2; tail -40 "$log" >&2; return 1
    fi
  done
}

echo "── the offline bootstrap (testing/lib/bootstrap.sh)"
tree="$scratch/$repo"
bootstrap_offline "$root" "$tree" "$values" "$scratch/logs" > "$scratch/bootstrap.log" 2>&1 || {
  echo "FAIL: the offline bootstrap stopped" >&2; tail -40 "$scratch/bootstrap.log" >&2; exit 1; }
s01="$(git -C "$tree" rev-parse HEAD~1)"
# 01-product is the product's FIRST commit; the main it merges into has none
# of it. That base is stood in for by an empty commit, so `--changed` sees
# every file the landing adds — what the real pull request and merge plan.
s00="$(git -C "$tree" commit-tree "$(git -C "$tree" hash-object -t tree /dev/null)" -m "main before the product")"
echo "   2 phases placed and landed"

# ── 1. the product's one pull request ──────────────────────────────────────
echo "── 01-product's landing: install, the fixture render, typecheck, lint, test, build"
git -C "$tree" worktree add -q "$scratch/at-01" "$s01"
checks "$scratch/at-01" "$scratch/checks-01.log"
# vitest colours its summary; the counts are read with the colour stripped.
sed 's/\x1b\[[0-9;]*m//g' "$scratch/checks-01.log" > "$scratch/checks-01.txt"
grep -Eq "Tests +[0-9]+ passed" "$scratch/checks-01.txt" || { echo "FAIL: the tests ran no test" >&2; exit 1; }
if grep -Eq "Tests +.*[0-9]+ failed" "$scratch/checks-01.txt"; then echo "FAIL: a test failed" >&2; exit 1; fi
grep -q "\[check-bundle\] dist/index.js is dependency-free ESM" "$scratch/checks-01.log" \
  || { echo "FAIL: the build did not run upstream's bundle guard" >&2; exit 1; }
echo "   $(grep -cE 'Tests +[0-9]+ passed' "$scratch/checks-01.txt") test packages green; the bundle guard passed"
# The landing's build is done; its tree is not needed again, and the disk is shared.
git -C "$tree" worktree remove --force "$scratch/at-01"

# ── 2. the stage lane, as a pull request plans it ──────────────────────────
echo "── the stage lane: every run step the PR plan gives bot@stage, in a staged job tree"
(cd "$tree" && orun plan --intent intent.yaml --trigger github-pull-request --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-pr.json") > "$scratch/plan-pr.log" 2>&1 \
  || { echo "FAIL: orun plan (pull request)" >&2; tail -15 "$scratch/plan-pr.log" >&2; exit 1; }
(cd "$tree" && orun plan --intent intent.yaml --trigger github-push-main --changed \
   --base "$s00" --head "$s01" --env stage --output "$scratch/plan-push.json") > "$scratch/plan-push.log" 2>&1 \
  || { echo "FAIL: orun plan (push to main)" >&2; tail -15 "$scratch/plan-push.log" >&2; exit 1; }
python3 - "$scratch/plan-pr.json" "$scratch/plan-push.json" "$scratch/steps" "$tree" <<'PY'
import json, pathlib, sys
import yaml
plan, push = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
out = pathlib.Path(sys.argv[3]); out.mkdir()
tree = pathlib.Path(sys.argv[4])
job = next(j for j in plan["jobs"] if j["component"] == "bot" and j["environment"] == "stage")
params = yaml.safe_load((tree / "apps/bot/component.yaml").read_text())["spec"]["parameters"]
order = []
for s in job["steps"]:
    if "use" in s:
        continue
    order.append(s["id"])
    (out / f"{s['id']}.sh").write_text(s.get("run") or "")
    (out / f"{s['id']}.wd").write_text(s.get("working-directory") or ".")
    if s.get("scope"):
        (out / f"{s['id']}.scope").write_text(s["scope"])
(out / "order").write_text("\n".join(order) + "\n")
(out / "path").write_text(job.get("path") or "apps/bot")
(out / "profile").write_text(job["profile"])
(out / "node").write_text(params["nodeVersion"])
(out / "pnpm").write_text(params["pnpmVersion"])
for k, v in (job.get("env") or {}).items():
    (out / "env").open("a").write(f"export {k}={json.dumps(v)}\n")
(out / "secrets").write_text("\n".join(r["asEnv"] for r in job.get("secretRefs") or []))
dep = next(j for j in push["jobs"] if j["component"] == "bot" and j["environment"] == "stage")
assert dep["profile"].endswith(".deploy"), dep["profile"]
(out / "smoke-step.sh").write_text(next(s for s in dep["steps"] if s["id"] == "smoke")["run"])
PY
order="$(tr '\n' ' ' < "$scratch/steps/order")"
echo "   $(cat "$scratch/steps/profile"): $order"
for need in install-workspace-dependencies verify-worker-structure build-worker typecheck-worker deploy-dry-run; do
  grep -qx "$need" "$scratch/steps/order" || { echo "FAIL: the stage lane plans no $need step" >&2; exit 1; }
done
[ "$(grep -n -x verify-worker-structure "$scratch/steps/order" | cut -d: -f1)" -lt "$(grep -n -x build-worker "$scratch/steps/order" | cut -d: -f1)" ] \
  || { echo "FAIL: the structure check is planned after the build" >&2; exit 1; }
grep -qx WIRING_CLOUDFLARE_KV_STAGE "$scratch/steps/secrets" \
  || { echo "FAIL: the stage lane does not resolve WIRING_CLOUDFLARE_KV_STAGE" >&2; exit 1; }
node_major="$(node -p 'process.versions.node.split(".")[0]')"
[ "$node_major" = "$(cat "$scratch/steps/node")" ] || { echo "FAIL: node $node_major here, the lane sets up $(cat "$scratch/steps/node")" >&2; exit 1; }
[ "$(pnpm --version)" = "$(cat "$scratch/steps/pnpm")" ] || { echo "FAIL: pnpm $(pnpm --version) here, the lane sets up $(cat "$scratch/steps/pnpm")" >&2; exit 1; }
echo "   setup-node $node_major and setup-pnpm $(pnpm --version) stand in for the lane's \`use:\` steps"

# What the platform resolves into the job before its first step: the wiring
# document the KV root lease-published, with a namespace id no fixture
# carries, so the built config and the dry run prove which document they
# came from.
kv_id="5ca1ab1e5ca1ab1e5ca1ab1e0000a001"
export WIRING_CLOUDFLARE_KV_STAGE='{"app_kv_id":"'"$kv_id"'","app_kv_title":"stg-'"$repo"'-app-kv-stage"}'
export WIRING_CLOUDFLARE_KV_PROD='{"app_kv_id":"5ca1ab1e5ca1ab1e5ca1ab1e0000a003","app_kv_title":"prod-'"$repo"'-app-kv-prod"}'

work="$tree/.orun/runs/e2e/bot.stage.verify-deploy/work"
install_scope="$(cat "$scratch/steps/install-workspace-dependencies.scope" 2>/dev/null || echo job)"
if [ "$install_scope" = lane ]; then
  (cd "$tree" && bash -e "$scratch/steps/install-workspace-dependencies.sh") > "$scratch/install-lane.log" 2>&1 \
    || { echo "FAIL: the lane's install step" >&2; tail -30 "$scratch/install-lane.log" >&2; exit 1; }
  python3 "$here/lib/stage-job.py" "$tree" "$work" --shared-deps
else
  python3 "$here/lib/stage-job.py" "$tree" "$work"
  [ ! -e "$work/node_modules" ] || { echo "FAIL: the staged tree carries node_modules it should install" >&2; exit 1; }
fi
for built in apps/bot/dist apps/bot/.wrangler packages/core/dist packages/web/dist; do
  [ ! -e "$work/$built" ] || { echo "FAIL: the staged tree carries build output ($built)" >&2; exit 1; }
done
[ ! -e "$work/apps/bot/.dev.vars" ] || { echo "FAIL: the staged tree carries a .dev.vars" >&2; exit 1; }
echo "   staged: $(realpath --relative-to="$tree" "$work"); install scope: $install_scope; no build output"

while IFS= read -r step; do
  [ -n "$step" ] || continue
  if [ "$step" = install-workspace-dependencies ] && [ "$install_scope" = lane ]; then
    echo "   · $step (lane-scoped: ran once in the source tree)"; continue
  fi
  echo "   ▸ $step"
  # The runner's per-job environment: the job's env (intent environment
  # `env:`), its resolved secrets (exported above) and ORUN_ENVIRONMENT; the
  # step runs in the component's directory.
  if ! (cd "$work/$(cat "$scratch/steps/path")/$(cat "$scratch/steps/$step.wd")" && \
        { [ -f "$scratch/steps/env" ] && source "$scratch/steps/env"; true; } && \
        export ORUN_ENVIRONMENT=stage && bash -e "$scratch/steps/$step.sh") > "$scratch/$step.log" 2>&1; then
    echo "FAIL: the stage lane's $step step" >&2; tail -40 "$scratch/$step.log" >&2; exit 1
  fi
done < "$scratch/steps/order"
grep -q "\"$kv_id\"" "$work/apps/bot/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage namespace id from its wiring document" >&2; exit 1; }
grep -q '"stage": {' "$work/apps/bot/wrangler.jsonc" \
  || { echo "FAIL: the lane's build did not render the stage environment the deploy names (--env stage)" >&2; exit 1; }
grep -Eq "env\.DATABASE \($kv_id\) +KV Namespace" "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run does not bind DATABASE to the stage namespace" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
grep -Eq 'env\.ENVIRONMENT \("stage"\)' "$scratch/deploy-dry-run.log" \
  || { echo "FAIL: the dry run did not resolve env.stage (ENVIRONMENT=stage)" >&2; tail -20 "$scratch/deploy-dry-run.log" >&2; exit 1; }
grep -q "\[check-bundle\]" "$scratch/build-worker.log" || { echo "FAIL: the lane's build ran no bundle guard" >&2; exit 1; }
echo "   the built config binds DATABASE to the stage document's namespace ($kv_id) under env.stage;"
echo "   the dry run accepts it, ENVIRONMENT=\"stage\"; the bundle guard ran in the lane"

# ── 3. serve it with no token, and smoke it as the deploy does ─────────────
serve() { # LOG — wrangler dev --env stage over the staged Worker; sets $url and $dev_pid
  local port iport
  port="$(free_port)"; iport="$(free_port)"
  (cd "$work/apps/bot" && exec setsid pnpm exec wrangler dev --local --config wrangler.jsonc --env stage \
     --ip 127.0.0.1 --port "$port" --inspector-port "$iport" --show-interactive-dev-session=false) \
     > "$1" 2>&1 < /dev/null &
  dev_pid=$!; pids+=("$dev_pid")
  url="http://127.0.0.1:$port"
  for _ in $(seq 1 90); do
    curl -s -o /dev/null "$url/health" && return 0
    kill -0 "$dev_pid" 2>/dev/null || { echo "FAIL: wrangler dev exited" >&2; tail -30 "$1" >&2; return 1; }
    sleep 1
  done
  echo "FAIL: wrangler dev never answered" >&2; tail -30 "$1" >&2; return 1
}

echo "── wrangler dev --env stage over the staged Worker, with no bot token (a fresh product)"
serve "$scratch/dev-1.log"
echo "   ▸ the deploy profile's planned smoke step: the webhook binding, then /health"
# Like every step, it runs in the component's directory.
(cd "$work/apps/bot" && DEPLOYED_URL="$url" ORUN_ENVIRONMENT=stage bash "$scratch/steps/smoke-step.sh") > "$scratch/smoke-1.log" 2>&1 \
  || { echo "FAIL: the planned smoke step refused a bot with no token" >&2; tail -20 "$scratch/smoke-1.log" >&2; exit 1; }
grep -q "bind-webhook: no TELEGRAM_TOKEN stored for stage" "$scratch/smoke-1.log" \
  || { echo "FAIL: the webhook binding did not say it had no token to bind" >&2; cat "$scratch/smoke-1.log" >&2; exit 1; }
if (cd "$work/apps/bot" && DEPLOYED_URL="$url" ORUN_ENVIRONMENT=prod bash -c "$(python3 -c "import yaml,sys;print(yaml.safe_load(open(sys.argv[1]))['spec']['parameters']['smokeCommand'])" "$tree/apps/bot/component.yaml")") >/dev/null 2>&1; then
  echo "FAIL: the smoke passed prod's check against the stage Worker — it does not read the environment" >&2; exit 1
fi
echo "   ▸ …a named no-op with no token, and it refuses the stage Worker as prod"

python3 - "$url" "$values" <<'PY'
import html, json, sys, urllib.error, urllib.request
base, values = sys.argv[1], json.load(open(sys.argv[2]))
name, repo, org = values["productname"], values["reponame"], values["githuborg"]
problems = []
def bad(m): problems.append(m)
def req(path, body=None, headers=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(base + path, data=data, headers=headers or {}, method="POST" if data else "GET")
    try:
        with urllib.request.urlopen(r, timeout=30) as resp:
            return resp.status, resp.headers.get("content-type", ""), resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get("content-type", ""), e.read()

s, ct, body = req("/health")
health = json.loads(body)
if s != 200 or health != {"status": "ok", "name": name, "environment": "stage", "kv": "ok",
                          "configured": False, "telegram": "connect a bot token"}:
    bad(f"/health answered {s} {health}")
for path in ("/", "/admin", "/init", "/help"):
    s, ct, body = req(path)
    page = body.decode()
    if s != 200 or not ct.startswith("text/html") or f"<title>{html.escape(name, quote=False)}</title>" not in page:
        bad(f"{path} answered {s} {ct} without the product's <title>")
    if "<title>ChatGPT-Telegram-Workers</title>" in page:
        bad(f"{path} still carries upstream's title")
s, _, body = req("/rpc", {"method": "pages.info", "params": {}})
info = json.loads(body).get("result") or {}
if info.get("name") != name or info.get("repoUrl") != f"https://github.com/{org}/{repo}" or info.get("hasToken") is not False:
    bad(f"pages.info is {info}")
s, _, body = req("/init/bind", {}, {"Authorization": "Bearer 123:anything"})
if s != 401:
    bad(f"POST /init/bind with no token on the Worker answered {s}, not 401")
s, _, _ = req("/no-such-route")
if s != 404:
    bad(f"/no-such-route answered {s}, want 404")
if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   /health {json.dumps(health)}")
print("   /, /admin, /init and /help carry the product's name; pages.info its repository; /init/bind refuses; a 404")
PY
stop_group "$dev_pid"

# ── 4. with a token: bound to Telegram, and answering ──────────────────────
echo "── the same Worker with the bot's secrets, as the deploy's secrets push leaves it"
token="123456789:AAE2e-stand-in-bot-token"
admin_id=4242
model_reply="Paris is the capital of France."
(exec setsid python3 "$here/lib/telegram-api.py" "$scratch/telegram.jsonl" "$scratch/telegram.port" --token "$token") \
  > "$scratch/telegram.log" 2>&1 < /dev/null &
pids+=("$!")
(exec setsid python3 "$here/lib/model-api.py" "$scratch/model.jsonl" "$scratch/model.port" --key sk-e2e --reply "$model_reply") \
  > "$scratch/model.log" 2>&1 < /dev/null &
pids+=("$!")
for _ in $(seq 1 50); do [ -s "$scratch/telegram.port" ] && [ -s "$scratch/model.port" ] && break; sleep 0.1; done
[ -s "$scratch/telegram.port" ] && [ -s "$scratch/model.port" ] || { echo "FAIL: the stand-in APIs did not start" >&2; exit 1; }
tg="http://127.0.0.1:$(cat "$scratch/telegram.port")"
llm="http://127.0.0.1:$(cat "$scratch/model.port")/v1"
printf 'TELEGRAM_TOKEN="%s"\nADMIN_ID="%s"\nADMIN_PASSWORD="e2e-admin-password"\n' "$token" "$admin_id" > "$work/apps/bot/.dev.vars"
serve "$scratch/dev-2.log"

echo "   ▸ the admin signs in with its password and points the bot at the stand-ins, through /admin's RPC"
python3 - "$url" "$tg" "$llm" <<'PY'
import json, sys, urllib.request
base, tg, llm = sys.argv[1:4]
def rpc(method, params=None, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = urllib.request.Request(base + "/rpc", data=json.dumps({"method": method, "params": params or {}}).encode(),
                               headers=headers, method="POST")
    with urllib.request.urlopen(r, timeout=30) as resp:
        body = json.loads(resp.read())
    if "error" in body:
        sys.exit(f"  ✕ {method}: {body['error']}")
    return body["result"]
info = rpc("admin.authInfo")
if not (info.get("passwordEnabled") and info.get("hasToken")):
    sys.exit(f"  ✕ admin.authInfo is {info} — the Worker did not get its secrets")
if json.loads(urllib.request.urlopen(base + "/health", timeout=30).read()).get("telegram") != "connected":
    sys.exit("  ✕ /health does not say the token is connected")
session = rpc("admin.login", {"password": "e2e-admin-password"})["token"]
config = rpc("admin.config.get", token=session)
if [p["id"] for p in config["chatProviders"]] != ["workers-ai"]:
    sys.exit(f"  ✕ a fresh bot's chat providers are {[p['id'] for p in config['chatProviders']]}, not the Workers AI default")
config["settings"]["telegramApiDomain"] = tg
config["settings"]["streamMode"] = False
config["chatProviders"].append({"id": "stand-in", "protocol": "chat-completions", "label": "Stand-in", "enabled": True,
                                "apiKey": "sk-e2e", "baseUrl": llm, "model": "e2e-model", "models": ["e2e-model"],
                                "extraParams": {}, "options": {}})
config["defaultChatProvider"] = "stand-in"
rpc("admin.config.save", config, token=session)
saved = rpc("admin.config.get", token=session)
stand_in = next(p for p in saved["chatProviders"] if p["id"] == "stand-in")
if stand_in.get("apiKey") == "sk-e2e" or not stand_in.get("hasApiKey"):
    sys.exit("  ✕ the admin page reads the provider's key back unmasked")
print("   admin.login by password; the Workers AI default read back; the stand-ins saved; the key masked on read")
PY

echo "   ▸ the deploy profile's planned smoke step, now with TELEGRAM_TOKEN in the job's environment"
(cd "$work/apps/bot" && DEPLOYED_URL="$url" ORUN_ENVIRONMENT=stage TELEGRAM_TOKEN="$token" bash "$scratch/steps/smoke-step.sh") > "$scratch/smoke-2.log" 2>&1 \
  || { echo "FAIL: the planned smoke step did not bind the webhook" >&2; tail -20 "$scratch/smoke-2.log" >&2; exit 1; }
grep -q "bind-webhook: the webhook is bound to $url" "$scratch/smoke-2.log" \
  || { echo "FAIL: the binding did not report a bound webhook" >&2; cat "$scratch/smoke-2.log" >&2; exit 1; }
if grep -q "$token" "$scratch/smoke-2.log"; then echo "FAIL: the smoke printed the bot token" >&2; exit 1; fi
echo "   ▸ an update from the admin, posted to the webhook"
python3 - "$url" "$token" "$admin_id" "$scratch/telegram.jsonl" "$scratch/model.jsonl" "$model_reply" <<'PY'
import json, sys, time, urllib.request
base, token, admin_id, tg_log, llm_log, reply = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4], sys.argv[5], sys.argv[6]
host = base.split("://", 1)[1]
problems = []
def bad(m): problems.append(m)
def calls():
    try:
        return [json.loads(l) for l in open(tg_log)]
    except FileNotFoundError:
        return []
bound = calls()
hook = [c for c in bound if c["method"] == "setWebhook"]
if not hook or hook[-1]["body"].get("url") != f"https://{host}/telegram/{token}/webhook":
    bad(f"setWebhook was {[c['body'] for c in hook]}, not the Worker's own URL")
if not any(c["method"] == "setMyCommands" for c in bound):
    bad("the binding published no commands (setMyCommands)")
menu = [c for c in bound if c["method"] == "setChatMenuButton"]
if not menu or ((menu[-1]["body"].get("menu_button") or {}).get("web_app") or {}).get("url") != f"https://{host}/admin":
    bad(f"the menu button is {[c['body'] for c in menu]}, not the admin Mini-App")
before = len(calls())
question = "What is the capital of France?"
update = {"update_id": 1, "message": {"message_id": 10, "date": int(time.time()), "text": question,
          "chat": {"id": admin_id, "type": "private"}, "from": {"id": admin_id, "is_bot": False, "first_name": "Sam"}}}
r = urllib.request.Request(f"{base}/telegram/{token}/webhook", data=json.dumps(update).encode(),
                           headers={"Content-Type": "application/json"}, method="POST")
with urllib.request.urlopen(r, timeout=60) as resp:
    if resp.status != 200:
        bad(f"the webhook answered {resp.status}")
asked = [json.loads(l) for l in open(llm_log)] if __import__("os").path.exists(llm_log) else []
if not asked or not any(question in json.dumps(m) for m in asked[-1].get("messages", [])):
    bad(f"the model was not asked the user's message: {asked[-1:] }")
sent = [c for c in calls()[before:] if c["method"] in ("sendMessage", "editMessageText")]
if not any(c["body"].get("chat_id") == admin_id and reply in (c["body"].get("text") or "") for c in sent):
    bad(f"the model's reply was not sent to the chat: {[(c['method'], c['body'].get('text')) for c in sent]}")
if problems:
    for p in problems:
        print(f"  ✕ {p}", file=sys.stderr)
    sys.exit(1)
print(f"   bound: setWebhook at https://{host}/telegram/<token>/webhook, the commands, the admin menu button")
print(f"   answered: the model asked {question!r}, its reply sent to chat {admin_id}")
PY
stop_group "$dev_pid"

echo "e2e.test.sh: ok"
