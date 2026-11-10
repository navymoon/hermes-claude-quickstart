#!/bin/bash
# Launch the Hindsight API with a clean environment (no Hermes PYTHONPATH leakage).
set -a; . "$HOME/.hermes-quickstart/hindsight/service.env"; set +a
unset PYTHONPATH PYTHONHOME PYTHONPYCACHEPREFIX
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
exec "$HOME/.local/bin/hindsight-api" --no-access-log
