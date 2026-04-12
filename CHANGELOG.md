# Changelog

All notable changes to "Batch Ventoy Deployer" will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.2.0] - 2026-04-12
### Added
- `SUMMON_COMMAND` variable in `defaults.conf` to customise the global command name without editing scripts
- `APP_NAME` variable in `defaults.conf` to decouple the internal system path from the summon command
- `--update` flag to trigger re-setup without manually deleting the marker file
- `--help` flag with usage summary and dependency list
- `install.sh` copies itself to `/usr/local/share/$APP_NAME/` so `--update` can invoke it from the system path
- Signal trap cleans up mount points on interrupt
- System disk guard — script refuses to format the disk hosting the root filesystem
- Input validation against `lsblk` before any disk is touched
- Early abort if no `.iso` files are found in `$ISO_SRC` before any formatting begins
- Disk space check against total ISO size before copying
- SHA-256 checksum verification on Ventoy download
- Post-copy integrity check via `rsync --checksum`
- `[n/total]` progress counter across drives
- All output logged to `/var/log/ventoyfleet.log` via `tee`

### Changed
- Marker file now stores Ventoy version and active summon command, enabling clean rename detection on `--update`
- Old summon command binary removed from `/usr/local/bin/` when `SUMMON_COMMAND` changes between installs
- Per-device confirmation replaced with a single upfront prompt listing all selected devices with model and size allows the process to run unattended after one confirmation
- All user-facing output routed through `lib/ui.sh` helper functions in preparation for a Zenity GUI layer
- Support files installed to `/usr/local/share/$APP_NAME/`, main script to `/usr/local/bin/$SUMMON_COMMAND`

### Fixed
- Tar extraction was deleting the extracted directory instead of the `.tar.gz` archive
- `chmod -R 777` removed — rsync runs without relaxing partition permissions
- `ventoy_mnt` initialised before signal trap to prevent unbound variable errors on early interrupt

---

## [0.1.0] - 2026-04-11
### Added
- A proper release on the project's [Github page](https://github.com/alnk-n/BatchVentoyDeployer)
- Automatic first-run setup: installs curl, Zenity, and downloads Ventoy2Disk
- Automatically copies ISOs  from `~/ISOs` to all selected drives after formatting
- Basic disk listing and text-prompt drive selection
- Proper file structure (config and lib folders, initial install script and a changelog).

---