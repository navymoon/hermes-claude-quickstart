#!/usr/bin/env bash
# 같은 Slack 앱(같은 Hermes 프로필)을 다른 워크스페이스에 추가 설치합니다.
# 앱 하나 = App-Level Token 하나로 여러 워크스페이스 이벤트를 받고, 워크스페이스마다 봇 토큰이
# 하나씩 생깁니다. 봇 토큰은 Infisical의 SLACK_BOT_TOKEN(쉼표 구분)에 추가됩니다.
set -euo pipefail
QS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"
. "$QS_DIR/lib/common.sh"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ -n "${QS_PROFILE:-}" ] || die "먼저 ./install.sh 를 실행하세요."
REDIRECT="https://localhost/"

cat <<EOF

  1) https://api.slack.com/apps → '$QS_BOT_NAME' 앱 → Manage Distribution
     → 체크리스트 확인 후 'Activate Public Distribution'
     (Slack 앱 디렉터리에 올라가는 게 아니라, 링크를 아는 워크스페이스만 설치 가능해집니다.
      OAuth Redirect URL '$REDIRECT' 은 매니페스트에 이미 들어 있습니다.)
  2) Basic Information → App Credentials 에서 Client ID / Client Secret 확인
EOF
ask CLIENT_ID "Client ID"
read_secret CLIENT_SECRET "Client Secret"

SCOPES="$(python3 -c 'import json,sys;print(",".join(json.load(open(sys.argv[1]))["oauth_config"]["scopes"]["bot"]))' "$STATE_DIR/slack-manifest.json")"
URL="https://slack.com/oauth/v2/authorize?client_id=${CLIENT_ID}&scope=${SCOPES}&redirect_uri=${REDIRECT}"
cat <<EOF

  3) 아래 링크를 브라우저에서 열고, 오른쪽 위에서 '추가할 워크스페이스'를 고른 뒤 허용하세요.
     (그 워크스페이스 관리자 승인이 필요할 수 있습니다)

     $URL

  4) 허용하면 'localhost에 연결할 수 없음' 페이지가 뜹니다. 정상입니다.
     그 페이지 주소창의 URL 전체(https://localhost/?code=… )를 복사하세요.
EOF
ask BACK "주소창 URL 붙여넣기"
CODE="$(python3 -c 'import sys,urllib.parse as u;print(u.parse_qs(u.urlparse(sys.argv[1]).query).get("code",[""])[0])' "$BACK")"
[ -n "$CODE" ] || die "URL에서 code를 찾지 못했습니다."

RESP="$(curl -fsS https://slack.com/api/oauth.v2.access \
  --data-urlencode "client_id=$CLIENT_ID" --data-urlencode "client_secret=$CLIENT_SECRET" \
  --data-urlencode "code=$CODE" --data-urlencode "redirect_uri=$REDIRECT")"
unset CLIENT_SECRET
read -r OKV TEAM NEWTOK < <(printf '%s' "$RESP" | python3 -c '
import json,sys; d=json.load(sys.stdin)
print("1" if d.get("ok") else "0", (d.get("team") or {}).get("name","?").replace(" ","_"), d.get("access_token","-"))')
[ "$OKV" = 1 ] || die "Slack 토큰 교환 실패: $(printf '%s' "$RESP" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("error"))')"

CUR="$(infisical_get SLACK_BOT_TOKEN || true)"
case ",$CUR," in *",$NEWTOK,"*) ok "이미 등록된 워크스페이스입니다 ($TEAM)";;
  *) infisical_set SLACK_BOT_TOKEN "${CUR:+$CUR,}$NEWTOK"; ok "워크스페이스 추가: $TEAM";;
esac
unset NEWTOK CUR RESP

info "이 워크스페이스에서 봇과 대화할 내 Member ID도 허용 목록에 넣어야 합니다."
ask MEMBER_ID "그 워크스페이스에서의 내 Slack Member ID (U…)"
ALLOWED="$(get_profile_env SLACK_ALLOWED_USERS)"
case ",$ALLOWED," in *",$MEMBER_ID,"*) ;; *) set_profile_env SLACK_ALLOWED_USERS "${ALLOWED:+$ALLOWED,}$MEMBER_ID";; esac
ok "허용 사용자: $(get_profile_env SLACK_ALLOWED_USERS)"

hermes -p "$QS_PROFILE" gateway restart </dev/null && ok "게이트웨이 재시작 — 새 워크스페이스에서 봇에게 DM 보내 보세요."
