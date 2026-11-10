# Instructions for AI coding agents (Claude Code, Codex, …)

The user asked you to install this quickstart on their Mac. Do it like this:

1. Ask the user (in their language) for two **non-secret** names:
   - Hermes profile name — lowercase letters/digits/`-`, not `default` (e.g. `luna`)
   - Slack bot display name (e.g. `Luna`)
   Never suggest names based on who the user is (no "wife", "mom", etc.).
2. Run, from the repo root:
   ```bash
   QS_PROFILE=<profile> QS_BOT_NAME=<bot> ./install.sh
   ```
   It is resumable. Inside an agent it runs every automatic step and **exits with code 3**
   at the first step only a human can do, printing a "USER ACTION REQUIRED" box.
3. On exit code 3: relay the box to the user in plain words and wait.
   - Logins (Claude, Infisical) and the Slack web console need the user's browser.
   - The Infisical **Project ID** and Slack **Member ID** are not secret: you may pass them as
     `QS_INFISICAL_PROJECT_ID=…` / `QS_SLACK_MEMBER_ID=…` on the next run.
   - **Secret values (Slack tokens, passwords, API keys) must never go through this chat.**
     Tell the user to open Terminal.app and run `./install.sh` there themselves; it prompts
     with hidden input and stores the values in Infisical only. Do not write secrets to files,
     env vars, command lines, or memory.
4. Re-run step 2 after each human action until it finishes, then run `./bin/doctor.sh`
   and report its result honestly. If something fails, read the log it points to and fix
   the cause; don't claim success without doctor passing.
5. Adding another Slack workspace later: `./bin/slack-add-workspace.sh` — it needs a
   Client Secret, so the user runs it in Terminal.
