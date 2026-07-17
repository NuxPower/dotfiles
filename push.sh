#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_DIR="$SCRIPT_DIR"
readonly MANIFEST="$REPO_DIR/sync-paths.conf"
readonly SNAPSHOT_DIR="$REPO_DIR/rices/jakoolit"

dry_run=false
sync_only=false
push_changes=true

usage() {
    cat <<'EOF'
Usage: ./push.sh [--dry-run] [--sync-only] [--no-push]

  --dry-run   Show files that would be synchronized; change nothing.
  --sync-only Synchronize configs and package lists, but do not commit.
  --no-push   Synchronize and commit, but do not contact the remote.
EOF
}

log() {
    printf '[dotfiles-sync] %s\n' "$*"
}

notify() {
    local urgency="$1"
    shift
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency="$urgency" "Dotfiles Backup" "$*" >/dev/null 2>&1 || true
    fi
}

die() {
    log "ERROR: $*" >&2
    notify critical "$*"
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) dry_run=true ;;
        --sync-only) sync_only=true ;;
        --no-push) push_changes=false ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "Unknown argument: $arg" ;;
    esac
done

for command_name in git rsync pacman flock; do
    command -v "$command_name" >/dev/null 2>&1 || die "Required command is missing: $command_name"
done

[[ -f "$MANIFEST" ]] || die "Missing sync manifest: $MANIFEST"
git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "$REPO_DIR is not a Git repository"

git_dir="$(git -C "$REPO_DIR" rev-parse --git-dir)"
[[ "$git_dir" = /* ]] || git_dir="$REPO_DIR/$git_dir"
if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" || -f "$git_dir/MERGE_HEAD" ]]; then
    die "Git has an unfinished merge or rebase; resolve it before running the backup"
fi

# Prevent the timer and a manual invocation from racing each other.
exec 9>"$REPO_DIR/.git/dotfiles-sync.lock"
flock -n 9 || die "Another dotfiles sync is already running"

rsync_options=(
    --archive
    --delete
    --delete-excluded
    --human-readable
    --itemize-changes
    --exclude=.cache/
    --exclude='*.log'
    --exclude='*.tmp'
    --exclude='*.swp'
    --exclude='*.bak'
    --exclude='*~'
    --exclude=.DS_Store
)

if "$dry_run"; then
    rsync_options+=(--dry-run)
    log "Dry run; no files will be changed"
else
    mkdir -p "$SNAPSHOT_DIR"
fi

synced_count=0
while IFS= read -r relative_path || [[ -n "$relative_path" ]]; do
    relative_path="${relative_path%%#*}"
    relative_path="${relative_path%"${relative_path##*[![:space:]]}"}"
    relative_path="${relative_path#"${relative_path%%[![:space:]]*}"}"
    [[ -n "$relative_path" ]] || continue

    [[ "$relative_path" != /* && "$relative_path" != *..* ]] || die "Unsafe manifest path: $relative_path"

    source_path="$HOME/$relative_path"
    destination_path="$SNAPSHOT_DIR/$relative_path"

    if [[ ! -d "$source_path" ]]; then
        log "Skipping optional path that is not installed: ~/$relative_path"
        continue
    fi

    if ! "$dry_run"; then
        mkdir -p "$destination_path"
    fi
    log "Syncing ~/$relative_path"
    rsync "${rsync_options[@]}" -- "$source_path/" "$destination_path/"
    ((synced_count += 1))
done < "$MANIFEST"

((synced_count > 0)) || die "The manifest did not contain any existing directories"

if "$dry_run"; then
    log "Package lists would be refreshed"
    log "Dry run complete"
    exit 0
fi

mkdir -p "$REPO_DIR/pkg-lists"
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
pacman -Qqen | LC_ALL=C sort -u > "$temp_dir/pacman_list.txt"
pacman -Qqem | LC_ALL=C sort -u > "$temp_dir/aur_list.txt"

for package_file in pacman_list.txt aur_list.txt; do
    if [[ ! -f "$REPO_DIR/pkg-lists/$package_file" ]] || ! cmp -s "$temp_dir/$package_file" "$REPO_DIR/pkg-lists/$package_file"; then
        install -m 0644 "$temp_dir/$package_file" "$REPO_DIR/pkg-lists/$package_file"
        log "Updated pkg-lists/$package_file"
    fi
done

if "$sync_only"; then
    log "Sync-only run complete; Git was not modified"
    exit 0
fi

current_branch="$(git -C "$REPO_DIR" symbolic-ref --quiet --short HEAD)" || die "Cannot sync from a detached HEAD"

secret_scan_status=0
git -C "$REPO_DIR" grep --untracked -I -n -E \
    -e 'BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY|gh[pousr]_[A-Za-z0-9_]{30,}' \
    -- rices/jakoolit > "$temp_dir/secret-scan.txt" 2>/dev/null || secret_scan_status=$?
if ((secret_scan_status == 0)); then
    cat "$temp_dir/secret-scan.txt" >&2
    die "Possible private key or GitHub token detected; nothing was committed"
elif ((secret_scan_status > 1)); then
    die "The credential safety scan failed"
fi

git -C "$REPO_DIR" add -A -- .
if ! git -C "$REPO_DIR" diff --cached --quiet; then
    git -C "$REPO_DIR" -c commit.gpgsign=false commit -m "Auto-update: $(date +'%Y-%m-%d %H:%M')"
    log "Committed synchronized dotfiles"
else
    log "No new changes to commit"
fi

if ! "$push_changes"; then
    log "Push disabled for this run"
    exit 0
fi

# Fetch/rebase first so unattended runs do not fail indefinitely after a remote edit.
git -C "$REPO_DIR" fetch --quiet origin "$current_branch" || die "Could not fetch origin/$current_branch; the local commit is preserved for retry"

if git -C "$REPO_DIR" show-ref --verify --quiet "refs/remotes/origin/$current_branch"; then
    behind_count="$(git -C "$REPO_DIR" rev-list --count "HEAD..origin/$current_branch")"
    if ((behind_count > 0)); then
        log "Rebasing onto origin/$current_branch"
        git -C "$REPO_DIR" rebase "origin/$current_branch" || die "Automatic rebase failed; resolve it in $REPO_DIR"
    fi
fi

ahead_count="$(git -C "$REPO_DIR" rev-list --count "origin/$current_branch..HEAD")"
if ((ahead_count > 0)); then
    git -C "$REPO_DIR" push origin "HEAD:$current_branch" || die "Push failed; $ahead_count local commit(s) will be retried next run"
    log "Pushed $ahead_count commit(s) to origin/$current_branch"
    notify normal "Backup pushed successfully"
else
    log "Already up to date with origin/$current_branch"
    notify low "No changes to push"
fi
