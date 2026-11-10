#!/usr/bin/env bash
# 상태 점검. 비밀값은 출력하지 않고 "있음/없음"과 개수만 보여 줍니다.
set -uo pipefail
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
. "$QS_DIR/lib/common.sh"
# shellcheck disable=SC1090
. "$STATE_FILE" 2>/dev/null || die "먼저 ./install.sh 를 실행하세요."
FAIL=0; chk() { if eval "$2" >/dev/null 2>&1; then ok "$1"; else warn "$1 — 실패"; FAIL=1; fi; }

chk "hermes 설치"                 "command -v hermes"
chk "Claude 로그인 ($(claude_plan))" "claude_logged_in"
chk "Infisical 로그인"            "infisical_logged_in || security find-generic-password -s hermes-quickstart-infisical-client-id"
OUT="$("$STATE_DIR/bin/infisical-env.sh" 2>/dev/null)"
chk "Infisical → Hermes 비밀값 주입 ($(printf '%s\n' "$OUT" | grep -c '=') 개)" "[ -n \"\$OUT\" ]"
chk "  SLACK_APP_TOKEN 있음"        "printf '%s' \"\$OUT\" | grep -q '^SLACK_APP_TOKEN='"
N="$(printf '%s\n' "$OUT" | sed -n "s/^SLACK_BOT_TOKEN=//p" | tr -d \"\'\" | tr ',' '\n' | grep -c xoxb)"
chk "  SLACK_BOT_TOKEN 워크스페이스 ${N}곳" "[ \"$N\" -ge 1 ]"
chk "허용 사용자 설정 ($(get_profile_env SLACK_ALLOWED_USERS))" "[ -n \"\$(get_profile_env SLACK_ALLOWED_USERS)\" ]"
chk "Hindsight 서버 (127.0.0.1:${QS_HINDSIGHT_PORT:-8888})" "curl -fsS -m 5 http://127.0.0.1:${QS_HINDSIGHT_PORT:-8888}/health"
chk "프로필 '$QS_PROFILE' 모델=Claude 구독" "grep -q 'provider: claude-subscription-directsdk' $HOME/.hermes/profiles/$QS_PROFILE/config.yaml"
chk "프로필 기억=Hindsight 뱅크 '$QS_PROFILE'" "grep -q '\"bank_id\": \"$QS_PROFILE\"' $HOME/.hermes/profiles/$QS_PROFILE/hindsight/config.json"
chk "게이트웨이 실행 중" "hermes -p $QS_PROFILE gateway status 2>&1 | grep -qiE 'running|served'"
exit "$FAIL"
