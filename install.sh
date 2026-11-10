#!/usr/bin/env bash
# Hermes + Claude 구독 + Hindsight + Infisical + Slack 퀵스타트 (macOS, Apple Silicon)
#
#   git clone https://github.com/navymoon/hermes-claude-quickstart.git
#   cd hermes-claude-quickstart && ./install.sh
#
# 다시 실행해도 안전합니다(이미 끝난 단계는 건너뜀). 비밀값은 이 레포·설정파일·셸 기록에
# 남기지 않고 Infisical에만 저장합니다.
set -euo pipefail

QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$HOME/.hermes-quickstart"
STATE_FILE="$STATE_DIR/state.env"
HINDSIGHT_VERSION="${QS_HINDSIGHT_VERSION:-1.1.0}"
HINDSIGHT_PORT="${QS_HINDSIGHT_PORT:-8888}"
INFISICAL_VERSION="${QS_INFISICAL_VERSION:-0.45.4}"
MODEL="${QS_MODEL:-claude-opus-5-5[1m]}"
PROVIDER="claude-subscription-directsdk-experimental"
export PATH="$HOME/.local/bin:$PATH"

# shellcheck source=lib/common.sh
. "$QS_DIR/lib/common.sh"

mkdir -p "$STATE_DIR/bin" "$STATE_DIR/logs"
chmod 700 "$STATE_DIR"
touch "$STATE_FILE"; chmod 600 "$STATE_FILE"
# Saved progress fills in anything not given on the command line (explicit env vars win).
_ENV_OVERRIDES="$(env | grep -E '^QS_[A-Z_]+=' | sed 's/=.*//' || true)"
_saved_env() { local k; for k in $_ENV_OVERRIDES; do printf '%s=%q\n' "$k" "${!k}"; done; }
_ENV_SNAPSHOT="$(_saved_env)"
# shellcheck disable=SC1090
. "$STATE_FILE"
eval "$_ENV_SNAPSHOT"

[ "$(uname -s)" = Darwin ] || die "macOS 전용입니다."
[ "$(uname -m)" = arm64 ] || die "Apple Silicon(arm64) Mac 전용입니다."

# ── 0. 이름 정하기 ───────────────────────────────────────────────────────────
step "0/8 이름 정하기"
if [ -z "${QS_PROFILE:-}" ]; then
  while :; do
    ask QS_PROFILE "Hermes 프로필 이름 (영문 소문자/숫자/-, 예: luna)"
    [[ "$QS_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]] && [ "$QS_PROFILE" != default ] && break
    warn "영문 소문자로 시작하는 32자 이하, 'default' 제외"
  done
  save_state QS_PROFILE "$QS_PROFILE"
fi
[[ "$QS_PROFILE" =~ ^[a-z0-9][a-z0-9-]{0,30}$ ]] && [ "$QS_PROFILE" != default ] \
  || die "프로필 이름 '$QS_PROFILE' 사용 불가 (영문 소문자/숫자/-, 32자 이하, default 제외)"
save_state QS_PROFILE "$QS_PROFILE"
[ -n "${QS_BOT_NAME:-}" ] || ask QS_BOT_NAME "Slack에 보일 봇 이름 (예: Luna)"
save_state QS_BOT_NAME "$QS_BOT_NAME"
ok "프로필: $QS_PROFILE / 봇 이름: $QS_BOT_NAME"

# ── 1. Hermes ────────────────────────────────────────────────────────────────
step "1/8 Hermes Agent 설치"
if command -v hermes >/dev/null 2>&1; then
  ok "이미 설치됨: $(hermes --version 2>/dev/null | head -1)"
else
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --non-interactive
  command -v hermes >/dev/null 2>&1 || die "hermes 설치 실패. 위 로그를 확인하세요."
fi
command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh

# ── 2. Claude Code + 로그인 ──────────────────────────────────────────────────
step "2/8 Claude Code 설치 및 구독 로그인"
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash
fi
command -v claude >/dev/null 2>&1 || die "claude 설치 실패"
if ! claude_logged_in; then
  has_tty || need_human "Claude 로그인: 터미널에서 'claude auth login' 실행 → 브라우저에서 본인 Pro/Max 계정으로 로그인"
  info "브라우저가 열리면 '본인' Claude 계정(Pro/Max)으로 로그인하세요."
  claude auth login
fi
claude_logged_in || die "Claude 로그인이 확인되지 않습니다. 'claude auth login' 후 다시 실행하세요."
ok "Claude 로그인 확인 ($(claude_plan))"

# ── 3. Infisical ─────────────────────────────────────────────────────────────
step "3/8 Infisical CLI 설치 및 로그인"
if ! command -v infisical >/dev/null 2>&1; then
  install_infisical "$INFISICAL_VERSION"
fi
ok "$(infisical --version 2>/dev/null)"
if ! infisical_logged_in; then
  has_tty || need_human "Infisical 로그인:" \
    "  1) https://app.infisical.com 가입(무료)" \
    "  2) 터미널에서 'infisical login' 실행 → 브라우저 로그인"
  info "Infisical 계정이 없으면 https://app.infisical.com 에서 먼저 가입하세요(무료)."
  infisical login
fi
infisical_logged_in || die "Infisical 로그인이 확인되지 않습니다."
if [ -z "${QS_INFISICAL_PROJECT_ID:-}" ]; then
  has_tty || need_human "Infisical 웹(https://app.infisical.com)에서 프로젝트 'hermes-$QS_PROFILE' 생성 → Settings → Copy Project ID" \
    "(Project ID는 비밀값이 아님: 에이전트에게 알려 주면 QS_INFISICAL_PROJECT_ID=… 로 이어서 실행)"
  cat <<EOF

  Infisical 웹(https://app.infisical.com)에서:
    1) Secrets Management → Add Project → 이름 'hermes-$QS_PROFILE'
    2) 프로젝트 → Settings → 'Copy Project ID'
EOF
  ask QS_INFISICAL_PROJECT_ID "Project ID 붙여넣기"
fi
save_state QS_INFISICAL_PROJECT_ID "$QS_INFISICAL_PROJECT_ID"
QS_INFISICAL_ENV="${QS_INFISICAL_ENV:-prod}"; save_state QS_INFISICAL_ENV "$QS_INFISICAL_ENV"
QS_INFISICAL_PATH="${QS_INFISICAL_PATH:-/hermes}"; save_state QS_INFISICAL_PATH "$QS_INFISICAL_PATH"
infisical secrets folders create --projectId "$QS_INFISICAL_PROJECT_ID" --env "$QS_INFISICAL_ENV" \
  --path / --name "${QS_INFISICAL_PATH#/}" --silent >/dev/null 2>&1 || true
infisical export --projectId "$QS_INFISICAL_PROJECT_ID" --env "$QS_INFISICAL_ENV" \
  --path "$QS_INFISICAL_PATH" --format dotenv --silent >/dev/null \
  || die "Infisical 프로젝트($QS_INFISICAL_PROJECT_ID, env=$QS_INFISICAL_ENV)에 접근할 수 없습니다."
install -m 700 "$QS_DIR/bin/infisical-env.sh" "$STATE_DIR/bin/infisical-env.sh"
ok "Infisical 연결 확인 (프로젝트 $QS_INFISICAL_PROJECT_ID, $QS_INFISICAL_ENV:$QS_INFISICAL_PATH)"

# ── 4. Hindsight 기억 서버 ──────────────────────────────────────────────────
step "4/8 Hindsight 기억 서버 (로컬, 본인 Claude 구독으로 기억 추출)"
if ! uv tool list 2>/dev/null | grep -q "^hindsight-api v$HINDSIGHT_VERSION"; then
  # claude-agent-sdk: Hindsight's claude-code LLM provider (memory extraction via your Claude login)
  uv tool install --force --python 3.13 "hindsight-api==$HINDSIGHT_VERSION" --with claude-agent-sdk
fi
install_hindsight_service "$HINDSIGHT_PORT"
info "첫 실행은 기억용 모델/DB 내려받느라 몇 분 걸릴 수 있습니다"
wait_http "http://127.0.0.1:$HINDSIGHT_PORT/health" 900 || die "Hindsight가 뜨지 않습니다: $STATE_DIR/logs/hindsight.log"
ok "Hindsight 실행 중 (127.0.0.1:$HINDSIGHT_PORT, 재부팅 시 자동 시작)"

# ── 5. Hermes 프로필 ─────────────────────────────────────────────────────────
step "5/8 Hermes 프로필 '$QS_PROFILE' 구성"
PROFILE_HOME="$HOME/.hermes/profiles/$QS_PROFILE"
if [ ! -d "$PROFILE_HOME" ]; then
  hermes profile create "$QS_PROFILE" --description "$QS_BOT_NAME: 개인 비서" </dev/null
fi
hp() { hermes -p "$QS_PROFILE" "$@"; }
[ -d "$PROFILE_HOME/plugins/$PROVIDER" ] || hp plugins install claude-subscription-directsdk --yes-deps --enable </dev/null
[ -d "$PROFILE_HOME/plugins/hindsight" ] || hp plugins install hindsight --yes-deps --enable </dev/null
hp config set model.default "$MODEL" >/dev/null
hp config set model.provider "$PROVIDER" >/dev/null
hp config set model.base_url "process://$PROVIDER" >/dev/null
hp config set model.api_mode chat_completions >/dev/null
hp config set memory.provider hindsight >/dev/null
hp config set secrets.command.command "$STATE_DIR/bin/infisical-env.sh" >/dev/null 2>&1
hp config set secrets.command.helper_timeout_seconds 20 >/dev/null 2>&1
hp config set secrets.command.override_existing true >/dev/null 2>&1
hp config set secrets.command.enabled true >/dev/null 2>&1
hp config set display.platforms.slack.tool_progress false >/dev/null
mkdir -p "$PROFILE_HOME/hindsight"
render "$QS_DIR/templates/hindsight-config.json" "$PROFILE_HOME/hindsight/config.json"
if [ ! -f "$PROFILE_HOME/.qs-soul-installed" ]; then
  render "$QS_DIR/templates/SOUL.md" "$PROFILE_HOME/SOUL.md"
  touch "$PROFILE_HOME/.qs-soul-installed"
fi
hermes profile use "$QS_PROFILE" >/dev/null
ok "프로필 구성 완료 ($PROFILE_HOME)"

# ── 6. Slack 앱 ─────────────────────────────────────────────────────────────
step "6/8 Slack 앱 (워크스페이스 여러 곳에 한 앱)"
MANIFEST="$STATE_DIR/slack-manifest.json"
hp slack manifest --name "$QS_BOT_NAME" --write "$MANIFEST" >/dev/null
python3 "$QS_DIR/lib/manifest_patch.py" "$MANIFEST"
if [ -z "${QS_SLACK_DONE:-}" ]; then
  pbcopy < "$MANIFEST" 2>/dev/null || true
  has_tty || need_human "Slack 앱 만들기 (매니페스트: $MANIFEST — 클립보드에 복사됨):" \
    "  1) https://api.slack.com/apps → Create New App → From a manifest → 워크스페이스 선택 → 붙여넣기" \
    "  2) Basic Information → App-Level Tokens → Generate (scope: connections:write)" \
    "  3) Install App → Install to Workspace" \
    "  그 다음 터미널에서 ./install.sh 를 실행하면 토큰 2개를 (화면에 안 보이게) 물어봅니다."
  cat <<EOF

  [첫 번째(본인) 워크스페이스]
    1) https://api.slack.com/apps → Create New App → From a manifest
    2) 워크스페이스 선택 → 매니페스트 붙여넣기 (클립보드에 복사됨: $MANIFEST)
    3) Basic Information → App-Level Tokens → Generate (scope: connections:write) → xapp-… 복사
    4) Install App → Install to Workspace → Bot User OAuth Token(xoxb-…) 복사
    5) Slack에서 내 프로필 → ⋮ → 'Copy member ID' (U…)

EOF
  read_secret APP_TOKEN "App-Level Token (xapp-…)"
  read_secret BOT_TOKEN "Bot User OAuth Token (xoxb-…)"
  [[ "$APP_TOKEN" == xapp-* ]] || die "xapp- 로 시작해야 합니다"
  [[ "$BOT_TOKEN" == xoxb-* ]] || die "xoxb- 로 시작해야 합니다"
  MEMBER_ID="${QS_SLACK_MEMBER_ID:-}"; ask MEMBER_ID "내 Slack Member ID (U…)"
  infisical_set SLACK_APP_TOKEN "$APP_TOKEN"
  infisical_set SLACK_BOT_TOKEN "$BOT_TOKEN"
  unset APP_TOKEN BOT_TOKEN
  set_profile_env SLACK_ALLOWED_USERS "$MEMBER_ID"
  save_state QS_SLACK_DONE 1
fi
ok "Slack 토큰은 Infisical에, 허용 사용자는 프로필 .env에 저장됨"
info "다른 워크스페이스에도 같은 봇을 붙이려면 나중에: ./bin/slack-add-workspace.sh"

# ── 7. 게이트웨이(상시 실행) ────────────────────────────────────────────────
step "7/8 게이트웨이 상시 실행 (로그인 시 자동 시작)"
hp gateway install --start-now --start-on-login </dev/null || hp gateway restart </dev/null || true
sleep 5
hp gateway status 2>&1 | head -5 || true

# ── 8. 점검 ─────────────────────────────────────────────────────────────────
step "8/8 점검"
"$QS_DIR/bin/doctor.sh" || true
cat <<EOF

완료. Slack에서 '$QS_BOT_NAME' 봇에게 DM을 보내 보세요.
  - 비밀값 추가:   infisical secrets set --projectId $QS_INFISICAL_PROJECT_ID --env $QS_INFISICAL_ENV --path $QS_INFISICAL_PATH NAME=값
                   (추가 후 'hermes gateway restart' 해야 반영)
  - 워크스페이스 추가: ./bin/slack-add-workspace.sh
  - 상태 점검:     ./bin/doctor.sh
EOF
