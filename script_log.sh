#!/bin/bash
set -euo pipefail

# Runs the sync script, writes logs and (optionally) sends the log to Gotify.
# Every option below can be set here OR overridden from the environment.
# Options of run_sync.sh (REMOTE_HOST, REMOTE_USER, ...) are inherited from the environment too.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
# location of sync script (normally no need to edit)
SYNC_SCRIPT="${SYNC_SCRIPT:-$SCRIPT_DIR/run_sync.sh}"
# Log files: BACKUP_LOG is appended to on every run, LATEST_LOG only holds the last run
BACKUP_LOG="${BACKUP_LOG:-$SCRIPT_DIR/backup.log}"
LATEST_LOG="${LATEST_LOG:-$SCRIPT_DIR/latest.log}"

# Gotify notifications. Leave GOTIFY_TOKEN empty to disable them.
GOTIFY_URL="${GOTIFY_URL:-}"          
GOTIFY_TOKEN="${GOTIFY_TOKEN:-}"
GOTIFY_TITLE="${GOTIFY_TITLE:-Backup rsync on $(hostname)}"
GOTIFY_PRIORITY="${GOTIFY_PRIORITY:-5}"                  # priority on success
GOTIFY_PRIORITY_FAILURE="${GOTIFY_PRIORITY_FAILURE:-8}"  # priority on failure
# Only the last N lines of the log are sent
LOG_TAIL_LINES="${LOG_TAIL_LINES:-200}"

# ---------------------------------------------------------------------------
# Run Backup
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$BACKUP_LOG")" "$(dirname "$LATEST_LOG")"

# Do not abort on failure (notification should still be sent)
set +e
bash "$SYNC_SCRIPT" 2>&1 | tee -a "$BACKUP_LOG" | tee "$LATEST_LOG"
STATUS=${PIPESTATUS[0]}
set -e

# ---------------------------------------------------------------------------
# Notify
# ---------------------------------------------------------------------------
if [ -n "$GOTIFY_TOKEN" ]; then
    if [ -z "$GOTIFY_URL" ]; then
        echo "GOTIFY_TOKEN is set but GOTIFY_URL is empty, skipping notification" >&2
    else
        if [ "$STATUS" -eq 0 ]; then
            title="$GOTIFY_TITLE - OK ($(date))"; prio="$GOTIFY_PRIORITY"
        else
            title="$GOTIFY_TITLE - FAILED ($(date))"; prio="$GOTIFY_PRIORITY_FAILURE"
        fi
        # --form-string avoids curl interpreting a message starting with @ or <;
        # the token goes in a header so it does not show up in the process list.
        curl --fail --silent --show-error --max-time 30 \
            -H "X-Gotify-Key: $GOTIFY_TOKEN" \
            --form-string "title=$title" \
            --form-string "message=$(tail -n "$LOG_TAIL_LINES" "$LATEST_LOG")" \
            --form-string "priority=$prio" \
            "${GOTIFY_URL%/}/message" >/dev/null \
            || echo "Failed to send Gotify notification" >&2
    fi
fi

exit "$STATUS"
