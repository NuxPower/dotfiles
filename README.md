# Dotfiles backup

This repository snapshots the active desktop configuration before committing and
pushing it. JaKooLit continues to own the live files under `~/.config`, so its
updater can replace or migrate them normally. The snapshots live under
`rices/jakoolit/` in the same home-relative layout, for example:

```text
rices/jakoolit/.config/hypr/
rices/jakoolit/.config/waybar/
```

## Commands

```bash
./push.sh --dry-run    # preview the snapshot
./push.sh --sync-only  # update the snapshot without touching Git
./push.sh --no-push    # update and commit locally
./push.sh              # update, commit, rebase if needed, and push
```

Edit `sync-paths.conf` to add or remove a JaKooLit component. Missing components
are treated as optional, and cache/log/editor files are excluded automatically.
The script uses a lock to prevent overlapping runs and retries previously failed
pushes even when no new files changed.

## Legacy personal-rice links

The old links in `~/.config/rices/personal` were broken because their relative
paths no longer reached this repository. Run `./repair-legacy-links.sh` after
moving or cloning the repository; it creates absolute links and refuses to
overwrite real files.

The live JaKooLit directories are deliberately snapshots rather than symlinks.
Symlinking those directories into this repository can break JaKooLit's update
and migration scripts.

## Timer

`dotfiles-sync.timer` runs the backup once per day and shortly after boot if a
scheduled run was missed. Inspect it with:

```bash
systemctl --user status dotfiles-sync.timer
journalctl --user -u dotfiles-sync.service
```

The versioned units are in `systemd/.config/systemd/user/`. To restore them on a
new machine, copy those two files into `~/.config/systemd/user/`, then run:

```bash
systemctl --user daemon-reload
systemctl --user enable --now dotfiles-sync.timer
```
