#!/bin/sh
# Hermes secrets.command helper: prints KEY=VALUE lines from Infisical at Hermes startup.
# Hermes discards this script's stderr, so diagnostics never leak. Must be fast and non-interactive.
#
# Auth order:
#   1) Machine identity (recommended for an always-on gateway): client id/secret in the macOS
#      Keychain items "hermes-quickstart-infisical-client-id" / "...-client-secret".
#   2) Otherwise the interactive `infisical login` session saved on this Mac.
set -eu
STATE_FILE="${HOME}/.hermes-quickstart/state.env"
# shellcheck disable=SC1090
. "$STATE_FILE"
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
INF="$(command -v infisical)"

TOKEN_ARG=""
CID="$(security find-generic-password -s hermes-quickstart-infisical-client-id -w 2>/dev/null || true)"
if [ -n "$CID" ]; then
  CSEC="$(security find-generic-password -s hermes-quickstart-infisical-client-secret -w 2>/dev/null || true)"
  TOKEN="$("$INF" login --method universal-auth --client-id "$CID" --client-secret "$CSEC" --plain --silent 2>/dev/null)"
  TOKEN_ARG="--token=$TOKEN"
fi

# shellcheck disable=SC2086
exec "$INF" export --projectId "$QS_INFISICAL_PROJECT_ID" --env "${QS_INFISICAL_ENV:-prod}" \
  --path "${QS_INFISICAL_PATH:-/hermes}" --format dotenv --silent $TOKEN_ARG
