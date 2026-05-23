# BatchVentoyDeployer

A lightweight Linux CLI tool for batch-formatting USB drives with
[Ventoy](https://github.com/ventoy/Ventoy) and syncing ISO files.
Designed for sysadmins and labs that need to prepare multiple bootable
drives in one operation.

## Features

- Batch Ventoy installation across multiple drives in one run
- Parallel drive processing: all drives format and copy simultaneously
- Automatic ISO sync from a configured source directory (`~/ISOs` by default)
- GUI drive selection via Zenity when a display is available, with full terminal fallback for headless/SSH use
- Pre-flight validation: system disk guard, space check, early ISO presence check
- SHA-256 verified Ventoy download
- All output logged to `/var/log/batchventoydeployer.log`

## Requirements

- Debian/Ubuntu-based Linux (uses `apt-get`)
- Bash 4.0+
- Root access (`sudo`)
- Internet connection for first-time Ventoy download
- Dependencies installed automatically by `install.sh`: `curl`, `zenity`, `rsync`, `exfat-fuse`, `exfatprogs`, `parted`

## Quick Start

```bash
git clone https://github.com/alnk-n/BatchVentoyDeployer.git
cd BatchVentoyDeployer
make install
```

Place your `.iso` files in `~/ISOs`, then run:

```bash
sudo ventoy
```

## Installation

### With Make (recommended)

| Command          | Effect                                              |
|------------------|-----------------------------------------------------|
| `make install`   | First-time setup                                    |
| `make update`    | Re-run setup; re-downloads Ventoy if version changed |
| `make uninstall` | Remove all installed files                          |

### Manual

```bash
sudo ./install.sh           # install
sudo ./install.sh --update  # update
```

## Usage

```
sudo ventoy [--help|--update]
```

| Flag       | Description                                           |
|------------|-------------------------------------------------------|
| `--help`   | Show usage information and exit (no sudo required)    |
| `--update` | Re-run setup (re-downloads Ventoy if version changed) |

### GUI vs Terminal Mode

When run from a desktop session with `$DISPLAY` or `$WAYLAND_DISPLAY` set,
BatchVentoyDeployer uses Zenity dialogs for drive selection and confirmation.
On headless systems or over plain SSH it falls back to terminal prompts automatically.

> **Note for sudo users:** `sudo` strips display environment variables by default.
> To use the GUI under sudo, run `sudo -E ventoy` or add the following to your
> sudoers file (`sudo visudo`):
> ```
> Defaults env_keep += "DISPLAY WAYLAND_DISPLAY"
> ```

## Configuration

Edit `/usr/local/share/batchventoydeployer/config/defaults.conf` (as root):

| Variable         | Default                                    | Description                                       |
|------------------|--------------------------------------------|---------------------------------------------------|
| `VENTOY_VERSION` | `1.1.11`                                   | Ventoy version to download                        |
| `APP_NAME`       | `batchventoydeployer`                      | Internal directory name under `/usr/local/share/` |
| `SUMMON_COMMAND` | `ventoy`                                   | Command name placed in `/usr/local/bin/`          |
| `ISO_SRC`        | `~/ISOs` of the invoking user              | Directory scanned for `.iso` files                |
| `LOG_FILE`       | `/var/log/batchventoydeployer.log`         | Append-only log of all runs                       |

### What gets installed

| Path | Contents |
|------|----------|
| `/usr/local/bin/ventoy` | Main executable (name set by `SUMMON_COMMAND`) |
| `/usr/local/share/batchventoydeployer/` | Support files: `lib/`, `config/`, `install.sh`, and the Ventoy release |

Changes to `SUMMON_COMMAND` take effect after running `make update`.
The old command binary is automatically removed from `/usr/local/bin/`.

## Contributing

Pull requests are welcome. This project follows the
[Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) standard.

**Format:** `<type>(<scope>): <description>`

Common types: `feat`, `fix`, `perf`, `refactor`, `docs`, `chore`, `test`

**Examples:**

```
feat(ui): add zenity progress bar for ISO copy
fix(disk): handle lsblk model names containing spaces
perf(main): skip rsync checksum for drives over 32 GB
docs(readme): add sudo -E note for GUI mode
chore: bump VENTOY_VERSION to 1.1.12
```

## Acknowledgements

Some of the more complex features in this project (parallel processing,
Zenity GUI integration) were implemented with assistance from
[Anthropic's Claude AI](https://claude.ai) due to limited time capacity.
All generated code has been reviewed for correctness and safety before
being committed.

Built on top of [Ventoy](https://github.com/ventoy/Ventoy) by longpanda.
