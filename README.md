# Hermes + Claude 퀵스타트 (macOS)

내 Mac에서 24시간 돌아가는 개인 AI 비서를 한 번에 세팅합니다. 비서와는 Slack DM으로 대화합니다.

- **두뇌:** [Hermes Agent](https://hermes-agent.nousresearch.com)가 **본인 Claude 구독(Pro/Max)** 으로 Claude Code를 구동합니다. API 키가 필요 없습니다.
- **기억:** 로컬 [Hindsight](https://github.com/vectorize-io/hindsight) 서버가 대화에서 기억을 뽑아 이 Mac에만 저장합니다.
- **비밀값:** [Infisical](https://infisical.com)에만 보관합니다. 설정 파일에는 `${NAME}` 같은 플레이스홀더만 남습니다.
- **대화:** Slack 앱 하나를 워크스페이스 여러 곳에 설치할 수 있습니다. 모두 같은 비서, 같은 기억으로 연결됩니다.

다른 사람의 서버, 계정, 토큰에는 의존하지 않습니다. 모든 것이 **설치한 사람 본인 계정**으로 돌아갑니다.

## 준비물

- Apple Silicon Mac (macOS 14 이상 권장), 디스크 여유 10GB 이상
- Claude Pro 또는 Max 구독 계정
- Slack 워크스페이스 (없으면 https://slack.com/get-started 에서 무료로 생성)
- Infisical 계정 (https://app.infisical.com 에서 무료 가입)

## 설치

```bash
git clone https://github.com/navymoon/hermes-claude-quickstart.git
cd hermes-claude-quickstart
./install.sh
```

**Claude Code에 맡기기:** Claude Code에서 "https://github.com/navymoon/hermes-claude-quickstart 설치해줘"라고 하면 됩니다. 자동으로 할 수 있는 단계는 Claude Code가 진행합니다(`CLAUDE.md` 참고). 로그인, Slack 앱 생성, 토큰 입력처럼 사람이 해야 하는 단계에서는 멈추고 무엇을 해야 하는지 알려 줍니다. 토큰 같은 비밀값은 채팅에 붙여넣지 마세요. 터미널에서 `./install.sh`를 실행해 직접 입력합니다.

직접 할 때는 설치 스크립트가 단계별로 묻는 것에 답하면 됩니다. 중간에 끊겨도 `./install.sh`를 다시 실행하면 끝난 단계는 건너뛰고 이어서 진행합니다.

| 단계 | 하는 일 | 내가 할 일 |
|---|---|---|
| 0 | 프로필 이름, 봇 이름 정하기 | 이름 입력 (예: `luna` / `Luna`) |
| 1 | Hermes 설치 | — |
| 2 | Claude Code 설치 | 브라우저에서 **본인** Claude 계정으로 로그인 |
| 3 | Infisical CLI 설치 | 로그인 → 웹에서 프로젝트 만들고 Project ID 붙여넣기 |
| 4 | Hindsight 기억 서버 설치, 자동 시작 등록 | — |
| 5 | Hermes 프로필 구성 (모델, 기억, 비밀값 연결) | — |
| 6 | Slack 앱 매니페스트 생성 | Slack에서 앱 만들기 → 토큰 2개, 내 Member ID 붙여넣기 |
| 7 | 게이트웨이 상시 실행 등록 | — |
| 8 | 점검 | — |

설치가 끝나면 Slack에서 봇에게 DM을 보내 보세요.

## 다른 워크스페이스에도 같은 비서 붙이기

```bash
./bin/slack-add-workspace.sh
```

같은 앱을 다른 워크스페이스에 설치하고, 새로 생긴 봇 토큰을 Infisical에 추가합니다. 비서와 기억은 그대로 하나입니다.

- 그 워크스페이스 관리자의 앱 설치 승인이 필요할 수 있습니다.
- 앱의 "Public Distribution"을 켜야 다른 워크스페이스에 설치할 수 있습니다. 이 설정을 켜도 앱 디렉터리에 공개되지는 않습니다. 설치 링크를 아는 사람만 설치할 수 있습니다.
- **보안:** 비서와 대화할 수 있는 사람은 `SLACK_ALLOWED_USERS`에 등록된 Member ID뿐입니다. 이 값은 프로필 `.env`에 들어 있습니다. 워크스페이스를 추가할 때 그곳에서 쓰는 **내** Member ID만 추가하세요. 다른 사람을 허용하면 그 사람도 이 Mac의 파일과 비서의 기억에 접근할 수 있습니다.

## 비밀값 관리 (Infisical)

- Hermes는 시작할 때 `~/.hermes-quickstart/bin/infisical-env.sh`로 Infisical 프로젝트의 `/hermes` 폴더 값을 받아 씁니다.
- 새 키를 추가하려면 Infisical 웹에서 넣거나 `infisical secrets set ...`을 쓰세요. 넣은 뒤 `hermes gateway restart`를 해야 반영됩니다.
- 비서도 같은 규칙을 따릅니다(`SOUL.md`). 키나 비밀번호를 기억해야 할 때는 Infisical에 저장하고, 설정과 기억에는 이름만 남깁니다.
- **선택: 머신 아이덴티티.** `infisical login` 세션이 만료되면 게이트웨이를 다시 시작할 때 비밀값을 못 받습니다. 오래 켜 둘 Mac이라면 Infisical에서 Machine Identity(Universal Auth)를 만들어 두세요. 그 Client ID와 Secret을 macOS 키체인에 넣으면 됩니다.
  ```bash
  security add-generic-password -U -s hermes-quickstart-infisical-client-id -a "$USER" -w   # 프롬프트에 붙여넣기
  security add-generic-password -U -s hermes-quickstart-infisical-client-secret -a "$USER" -w
  ```
  이 아이덴티티에는 해당 프로젝트의 읽기 권한만 주세요.

## 자주 쓰는 명령

```bash
./bin/doctor.sh              # 전체 상태 점검 (비밀값은 출력 안 함)
hermes gateway restart       # 설정/비밀값 바꾼 뒤
hermes gateway status
tail -f ~/.hermes-quickstart/logs/hindsight.log
hermes                       # 터미널에서 바로 대화
```

## 파일 위치

| 경로 | 내용 |
|---|---|
| `~/.hermes/profiles/<프로필>/` | 비서 설정, 대화 기록, 스킬 |
| `~/.hermes-quickstart/state.env` | 설치 진행 상태 (비밀값 없음: 프로필 이름, Infisical Project ID 등) |
| `~/.hermes-quickstart/hindsight/` | 기억 서버 실행 설정 |
| `~/Library/LaunchAgents/io.hermes-quickstart.hindsight.plist` | 기억 서버 자동 시작 |

## 제거

```bash
hermes gateway uninstall
launchctl bootout gui/$(id -u)/io.hermes-quickstart.hindsight
rm ~/Library/LaunchAgents/io.hermes-quickstart.hindsight.plist
# 기억/대화까지 지우려면 (되돌릴 수 없음):
# hermes profile delete <프로필>; rm -rf ~/.hermes-quickstart ~/.pg0
```

## 참고

- Claude 구독 연동은 Hermes 공식 플러그인 `claude-subscription-directsdk`(실험적)를 씁니다. 사용량은 본인 구독 한도에서 차감됩니다.
- Hindsight는 기억을 뽑을 때도 같은 Claude 로그인을 씁니다(`claude-sonnet-5-5`). 모델을 바꾸려면 `~/.hermes-quickstart/hindsight/service.env`를 수정하세요.
- 버전 고정값: `QS_HINDSIGHT_VERSION`, `QS_INFISICAL_VERSION`, `QS_MODEL` 환경변수로 덮어쓸 수 있습니다.

MIT License
