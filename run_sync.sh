#!/bin/bash
set -euo pipefail

# RSYNC SERVER BACKUP 
# This script allows for automatic dumping of mysql/mariadb databases inside docker containers as well as transfering them to
# a remote machine via rsync/ssh. 
#
# Every option below can be set here OR overridden from the environment, e.g.
#   REMOTE_HOST=backup.example.com ./run_sync.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
# Hostname or IP address of the backup destination machine (required)
REMOTE_HOST="${REMOTE_HOST:-}"
# Remote machine user (required)
REMOTE_USER="${REMOTE_USER:-}"
# Remote machine password. Leave empty when using SSH keys. Requires `sshpass` if set.
REMOTE_PASS="${REMOTE_PASS:-}"
# SSH port of the remote machine
SSH_PORT="${SSH_PORT:-22}"
# Path to an SSH private key (optional)
SSH_KEY="${SSH_KEY:-}"
# Extra options passed to ssh
SSH_OPTS="${SSH_OPTS:-}"
# Options passed to every rsync call (--delete makes the remote an exact mirror)
RSYNC_OPTS="${RSYNC_OPTS:-"--archive --delete"}"

# Enable / disable parts of the script
DB_BACKUP_ENABLED="${DB_BACKUP_ENABLED:-true}"
FILE_SYNC_ENABLED="${FILE_SYNC_ENABLED:-true}"

# Local directory to which database dumps are written (one subdirectory per container)
DBDUMPDIR="${DBDUMPDIR:-$SCRIPT_DIR/db_backup}"
# Remote directory to which the database dumps are synced
REMOTE_DB_DIR="${REMOTE_DB_DIR:-}"
# Regex matched against the container IMAGE name to find database containers
DB_IMAGE_PATTERN="${DB_IMAGE_PATTERN:-mysql|mariadb}"
# Extra options for mysqldump / mariadb-dump
DUMP_OPTS="${DUMP_OPTS:---single-transaction}"
# Days that dumps are kept locally. Old dumps are only removed if more than DAYS dumps exist.
DAYS="${DAYS:-2}"

# File containing path pairs to sync, one per line, in the format  /local/dir>/remote/dir
# Empty lines and lines starting with # are ignored.
PATHS_FILE="${PATHS_FILE:-$SCRIPT_DIR/paths.txt}"

# Show a list of all transferred files in the logs (true) or only a summary (false)
VERBOSE="${VERBOSE:-false}"

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------
: "${REMOTE_HOST:?REMOTE_HOST must be set}"
: "${REMOTE_USER:?REMOTE_USER must be set}"
if [ "$DB_BACKUP_ENABLED" = "true" ]; then
    : "${REMOTE_DB_DIR:?REMOTE_DB_DIR must be set when DB_BACKUP_ENABLED=true}"
fi

SSH_CMD="ssh -p $SSH_PORT"
[ -n "$SSH_KEY" ] && SSH_CMD+=" -i $SSH_KEY"
[ -n "$SSH_OPTS" ] && SSH_CMD+=" $SSH_OPTS"

RSYNC=(rsync)
if [ -n "$REMOTE_PASS" ]; then
    command -v sshpass >/dev/null || { echo "REMOTE_PASS is set but sshpass is not installed" >&2; exit 1; }
    export SSHPASS="$REMOTE_PASS"
    RSYNC=(sshpass -e rsync)
fi

if [ "$VERBOSE" = "true" ]; then
    OUTPUT_OPT="--verbose"
else
    OUTPUT_OPT="--stats"
fi

FAILURES=0
fail() { echo "ERROR: $*" >&2; FAILURES=$((FAILURES + 1)); }

exec_rsync() {
    # shellcheck disable=SC2086
    "${RSYNC[@]}" $RSYNC_OPTS $OUTPUT_OPT -e "$SSH_CMD -n" "$1" "$REMOTE_USER@$REMOTE_HOST:$2" </dev/null
}

echo "Starting backup at: $(date)"

# ---------------------------------------------------------------------------
# Database dumps
# ---------------------------------------------------------------------------
if [ "$DB_BACKUP_ENABLED" = "true" ]; then
    echo "Starting database dump..."
    # container detection: match on image name only
    mapfile -t CONTAINERS < <(docker ps --format '{{.Names}}\t{{.Image}}' \
        | awk -F'\t' -v p="$DB_IMAGE_PATTERN" '$2 ~ p {print $1}')

    echo "Containers found: ${CONTAINERS[*]:-none}"
    mkdir -p "$DBDUMPDIR"

    for c in "${CONTAINERS[@]}"; do
        # Database name (empty = dump all databases)
        db=$(docker exec "$c" sh -c 'printf %s "${MYSQL_DATABASE:-${MARIADB_DATABASE:-}}"') || { fail "cannot read env of $c"; continue; }
        label="${db:-all-databases}"
        dir="$DBDUMPDIR/$c"
        mkdir -p "$dir"
        out="$dir/$c-$label-$(date +%Y%m%d%H%M).sql.gz"

        echo "Dumping $c ($label) -> $out"
        if docker exec -e DUMP_OPTS="$DUMP_OPTS" "$c" sh -c '
                pw="${MYSQL_ROOT_PASSWORD:-${MARIADB_ROOT_PASSWORD:-}}"
                db="${MYSQL_DATABASE:-${MARIADB_DATABASE:-}}"
                if command -v mariadb-dump >/dev/null 2>&1; then d=mariadb-dump; else d=mysqldump; fi
                if [ -n "$db" ]; then set -- "$db"; else set -- --all-databases; fi
                MYSQL_PWD="$pw" exec "$d" -u root $DUMP_OPTS "$@"' \
            | gzip > "$out.part"; then
            mv "$out.part" "$out"
        else
            rm -f "$out.part"
            fail "dump of container $c failed"
            continue
        fi

        # Retention: only delete if more than $DAYS dumps exist for this container
        count=$(find "$dir" -maxdepth 1 -name '*.sql.gz' | wc -l)
        if [ "$count" -gt "$DAYS" ]; then
            find "$dir" -maxdepth 1 -name '*.sql.gz' -daystart -mtime "+$DAYS" -delete
        fi
    done

    echo "Starting rsync of dumped databases..."
    exec_rsync "$DBDUMPDIR/" "$REMOTE_DB_DIR" || fail "rsync of database dumps failed"
fi

# ---------------------------------------------------------------------------
# File sync
# ---------------------------------------------------------------------------
if [ "$FILE_SYNC_ENABLED" = "true" ]; then
    [ -r "$PATHS_FILE" ] || { echo "Cannot read PATHS_FILE: $PATHS_FILE" >&2; exit 1; }

    while IFS='>' read -r SRC DST <&3 || [ -n "${SRC:-}" ]; do
        # Skip blank lines and comments
        [[ -z "${SRC//[[:space:]]/}" || "$SRC" == \#* ]] && continue
        if [ -z "${DST:-}" ]; then
            fail "invalid line in $PATHS_FILE (expected SRC>DST): $SRC"
            continue
        fi
        SRC="${SRC%/}/"
        DST="${DST%/}/"

        echo "Running rsync for path-pair: SRC=$SRC DST=$DST"
        do_rsync "$SRC" "$DST" || fail "rsync of $SRC failed"
    done 3< "$PATHS_FILE"
fi

echo "Finished at: $(date) with $FAILURES error(s)"
[ "$FAILURES" -eq 0 ]
