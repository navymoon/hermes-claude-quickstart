"""Add the OAuth redirect URL used by bin/slack-add-workspace.sh to a Hermes Slack manifest."""
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    manifest = json.load(f)
oauth = manifest.setdefault("oauth_config", {})
urls = oauth.setdefault("redirect_urls", [])
if "https://localhost/" not in urls:
    urls.append("https://localhost/")
with open(path, "w", encoding="utf-8") as f:
    json.dump(manifest, f, ensure_ascii=False, indent=2)
