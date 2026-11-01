# rsync-server-backup

This script allows for the automatic dumping of mysql/mariadb databases inside docker containers as well as transferring them to a remote machine via rsync/ssh.

The database backup part of this application is based on the [database container backup scripts](https://github.com/ChristianLempa/scripts/tree/main/db-container-backup) by Christian Lempa.

# Dockerbackup script

This script allows for automatic dumping of mysql/mariadb databases inside docker containers as well as transfering them to a remote machine via rsync/ssh. The script is primarily made for usage on a specific VPS and not developed for general usage. Usage on other servers is also possible (might need to change parts of the config / script below) but not officially supported. The database backup part of this application is based on the [database container backup scripts](https://github.com/ChristianLempa/scripts/tree/main/db-container-backup) by Christian Lempa.

## Configuration

### Sync configuration

The following configuration options are available within the script (edit `run_sync.sh`):

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

### Logging and notifications

`script_log.sh` on the other hand is the script that should actually be run if you want logging. It also supports pushing to Gotify.

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

## Usage

If you want to run the script periodically, this can for example be done via cron:

    0 3 * * * /path/to/script_log.sh

