# shellcheck shell=bash
# Shared helpers for install.sh / bin/*.sh. Never echo secret values.

c() { printf '\033[%sm%s\033[0m' "$1" "$2"; }
step() { printf '\n%s\n' "$(c '1;36' "▶ $*")"; }
ok()   { printf '  %s %s\n' "$(c 32 ✓)" "$*"; }
info() { printf '  %s %s\n' "$(c 34 ·)" "$*"; }
warn() { printf '  %s %s\n' "$(c 33 !)" "$*"; }
die()  { printf '  %s %s\n' "$(c 31 ✗)" "$*" >&2; exit 1; }

STATE_DIR="${STATE_DIR:-$HOME/.hermes-quickstart}"
STATE_FILE="${STATE_FILE:-$STATE_DIR/state.env}"

# Interactive terminal available? False inside AI agents (Claude Code sets CLAUDECODE=1) or when
# QS_NONINTERACTIVE=1 — then steps that need a human stop with clear instructions instead of hanging.
has_tty() { [ -z "${CLAUDECODE:-}${QS_NONINTERACTIVE:-}" ] && { : </dev/tty; } 2>/dev/null; }
need_human() {  # need_human "what the person must do" — exits 3 so an agent can relay it
  cat >&2 <<EOF

  ┌─ 사람이 직접 해야 하는 단계 (USER ACTION REQUIRED) ─────────────────────
$(printf '%s\n' "$@" | sed 's/^/  │ /')
  │
  │ 끝나면 터미널(Terminal.app)에서 이어서 실행:  cd "$QS_DIR" && ./install.sh
  └──────────────────────────────────────────────────────────────────────────
EOF
  exit 3
}

ask() {  # ask VAR "prompt"   (non-secret; an env var of the same name skips the prompt)
  [ -n "${!1:-}" ] && return 0
  has_tty || need_human "입력 필요: $2" "(에이전트라면 환경변수 $1=… 로 넘겨도 됩니다. 비밀값이 아닌 경우만)"
  local __v; read -r -p "  ? $2: " __v </dev/tty
  [ -n "$__v" ] || die "값이 비어 있습니다"
  printf -v "$1" '%s' "$__v"
}
read_secret() {  # read_secret VAR "prompt"  (no echo, never stored outside Infisical; never via env/agent)
  has_tty || need_human "비밀값 입력 단계입니다: $2" \
    "비밀값은 AI 채팅에 붙여넣지 말고 터미널에서 직접 입력하세요."
  local __v; read -r -s -p "  ? $2 (입력 내용은 화면에 안 보임): " __v </dev/tty; echo
  [ -n "$__v" ] || die "값이 비어 있습니다"
  printf -v "$1" '%s' "$__v"
}
save_state() {  # non-secret progress only
  local k="$1" v="$2" tmp
  tmp="$(mktemp)"; grep -v "^$k=" "$STATE_FILE" > "$tmp" 2>/dev/null || true
  printf '%s=%q\n' "$k" "$v" >> "$tmp"; mv "$tmp" "$STATE_FILE"; chmod 600 "$STATE_FILE"
}
render() {  # render template dest   ({{PROFILE}} {{BOT_NAME}} {{PORT}} …)
  sed -e "s|{{PROFILE}}|${QS_PROFILE}|g" -e "s|{{BOT_NAME}}|${QS_BOT_NAME}|g" \
      -e "s|{{PORT}}|${HINDSIGHT_PORT:-8888}|g" -e "s|{{HOME}}|${HOME}|g" \
      -e "s|{{INFISICAL_PROJECT_ID}}|${QS_INFISICAL_PROJECT_ID:-}|g" \
      -e "s|{{INFISICAL_ENV}}|${QS_INFISICAL_ENV:-prod}|g" \
      -e "s|{{INFISICAL_PATH}}|${QS_INFISICAL_PATH:-/hermes}|g" "$1" > "$2"
}

claude_logged_in() { claude auth status 2>/dev/null | grep -q '"loggedIn": *true'; }
claude_plan() { claude auth status 2>/dev/null | sed -n 's/.*"subscriptionType": *"\([^"]*\)".*/\1/p'; }

infisical_logged_in() { infisical user get token --silent >/dev/null 2>&1; }
install_infisical() {
  local ver="$1" tmp base
  tmp="$(mktemp -d)"; base="https://github.com/Infisical/cli/releases/download/v$ver"
  curl -fsSL -o "$tmp/cli.tgz" "$base/cli_${ver}_darwin_arm64.tar.gz"
  curl -fsSL -o "$tmp/sums" "$base/checksums-darwin.txt"
  (cd "$tmp" && grep "cli_${ver}_darwin_arm64.tar.gz" sums | sed 's/cli_.*$/cli.tgz/' | shasum -a 256 -c -) \
    || die "Infisical 다운로드 체크섬 불일치"
  tar -xzf "$tmp/cli.tgz" -C "$tmp" infisical
  mkdir -p "$HOME/.local/bin"; install -m 755 "$tmp/infisical" "$HOME/.local/bin/infisical"
  rm -rf "$tmp"
}
infisical_set() {  # infisical_set NAME VALUE  — value goes through a 0600 temp file, never argv
  local f; f="$(mktemp)"; chmod 600 "$f"
  printf '%s=%s\n' "$1" "$2" > "$f"
  infisical secrets set --projectId "$QS_INFISICAL_PROJECT_ID" --env "$QS_INFISICAL_ENV" \
    --path "$QS_INFISICAL_PATH" --file "$f" --silent >/dev/null || { rm -f "$f"; die "Infisical 저장 실패: $1"; }
  rm -f "$f"; ok "Infisical에 저장: $1"
}
infisical_get() {  # infisical_get NAME → stdout (for scripts only)
  infisical secrets get "$1" --projectId "$QS_INFISICAL_PROJECT_ID" --env "$QS_INFISICAL_ENV" \
    --path "$QS_INFISICAL_PATH" --plain --silent 2>/dev/null
}
set_profile_env() {  # non-secret values only (e.g. allowlists)
  local envf="$HOME/.hermes/profiles/$QS_PROFILE/.env" tmp
  touch "$envf"; chmod 600 "$envf"
  tmp="$(mktemp)"; grep -v "^$1=" "$envf" > "$tmp" || true
  printf '%s=%s\n' "$1" "$2" >> "$tmp"; mv "$tmp" "$envf"; chmod 600 "$envf"
}
get_profile_env() { sed -n "s/^$1=//p" "$HOME/.hermes/profiles/$QS_PROFILE/.env" 2>/dev/null | tail -1; }

wait_http() {  # wait_http URL seconds
  local i=0; while [ "$i" -lt "$2" ]; do curl -fsS -m 3 "$1" >/dev/null 2>&1 && return 0; sleep 3; i=$((i+3)); done; return 1
}

install_hindsight_service() {
  local port="$1" svc="$STATE_DIR/hindsight" label="io.hermes-quickstart.hindsight"
  local plist="$HOME/Library/LaunchAgents/$label.plist"
  mkdir -p "$svc" "$STATE_DIR/logs" "$HOME/Library/LaunchAgents"
  HINDSIGHT_PORT="$port" render "$QS_DIR/templates/hindsight-service.env" "$svc/service.env"
  install -m 755 "$QS_DIR/templates/hindsight-run.sh" "$svc/run.sh"
  HINDSIGHT_PORT="$port" render "$QS_DIR/templates/hindsight.plist" "$plist"
  launchctl bootout "gui/$(id -u)/$label" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$plist"
}
