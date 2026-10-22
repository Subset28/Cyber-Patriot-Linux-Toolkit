# CyberPatriot Linux Toolkit (Mint / Ubuntu / Debian)

Modular hardening helper for CyberPatriot Linux images. It reads the README on the Desktop, makes a backup, runs one module at a time, and logs everything.

**Default is a dry run.** Nothing changes until you add `--apply`.

## Before you start

The toolkit looks for a file with "readme" in its name on each user's Desktop. It must be a `.txt` or `.html` file (or `.md`). Launcher files like `.desktop` are skipped, so save the README as `.txt` or `.html` first.

1. Read the competition README on the Desktop and write down:
   - Authorized administrators and users
   - Critical services (for example `ssh`)
   - Any required groups, ports, or software
   - Required and prohibited software
2. Check `config.env` and fill in anything the README says that the parser can't get.
3. Confirm the image is one the scoring allows. Check your team's competition rules before running anything on comp day.

## Quick start

Easiest: use the menu.

```bash
cd ~/cp-toolkit                    # or wherever you copied it
sudo bash cp_menu.sh
```

1. Choose **1** to see the users, admins, and services read from the README (no changes).
2. Choose **2** for a dry run. Read the whole output.
3. Fix `config.env` if anything is wrong.
4. Choose **3** and type `APPLY` to make changes.

Without the menu:

```bash
sudo bash cp_harden.sh --show      # print users, admins, and services from the README
sudo bash cp_harden.sh             # dry run: prints every change it would make
sudo bash cp_harden.sh --apply     # makes the changes
```

## Options

| Command | What it does |
|---|---|
| `sudo bash cp_harden.sh` | Dry run, all modules |
| `sudo bash cp_harden.sh --apply` | Make changes, all modules |
| `sudo bash cp_harden.sh --only ssh,firewall` | Run only these modules (dry run unless `--apply` is added) |
| `sudo bash cp_harden.sh --skip media` | Run everything except these modules |
| `sudo bash cp_harden.sh --list` | Print module names and exit |

Module names: `users`, `auth`, `guest`, `updates`, `sysctl`, `firewall`, `ssh`, `packages`, `media`, `perms`, `groups`, `forensics`, `services`, `audit`.

## Configuration: config.env

Leave a line commented to let the README fill it in. Uncomment it to override.

| Setting | Meaning |
|---|---|
| `ADMINS`, `USERS`, `SERVICES` | Override what the README parser finds |
| `NEW_ADMINS` | New admin accounts to create (forced password change at login). If unset, you are asked. |
| `NewUsers` | Standard (non-admin) accounts to create, e.g. `NewUsers=("belethor")`. Gets a generated password. |

Passwords: every authorized account (admins, users, new accounts) gets a generated 16-character password and must change it at next login. The passwords are saved to `new-passwords.txt` in the run folder, not shown on screen. You are not asked for passwords. Your own account, root, and any auto-login account are skipped.
| `GroupMembers` | Add users to groups, for example `GroupMembers=("candace:firesidegirls")` |
| `DeleteUnauthorizedHomes` | `1` (default): delete a removed user's home folder too. Listed users' homes are never touched. |
| `ALLOW_TCP_PORTS` | Ports to open in UFW besides SSH |
| `PASS_MAX_DAYS`, `PASS_MIN_DAYS`, `PASS_WARN_AGE`, `PASS_MIN_LEN` | Password aging and length |
| `FAILLOCK_DENY`, `FAILLOCK_UNLOCK` | Account lockout threshold and time |
| `MEDIA_EXT` | File extensions treated as media |
| `MEDIA_DIRS` | Folder names where media is deleted (default `music|downloads|videos`) |
| `BAD_PKGS` | Packages removed when installed (includes FTP servers and ManaPlus, Game Conqueror) |
| `PROTECTED_PKGS` | Packages never removed, even if listed in `BAD_PKGS` |

## What each module does

- **users**: removes accounts not on any list (skips the account you're logged in with), and removes admin rights from users who aren't authorized admins. Creates `NEW_ADMINS`.
- **auth**: password aging, password quality, lockout settings, and password history (`remember=5` in common-password).
- **guest**: turns off guest login on LightDM. Prints a note on other display managers.
- **updates**: full upgrade, automatic security updates.
- **sysctl**: network hardening settings in `/etc/sysctl.d/`.
- **firewall**: enables UFW, denies inbound by default, allows SSH and `ALLOW_TCP_PORTS`.
- **ssh**: hardens `sshd` (no root login, no empty passwords) and restarts it only after `sshd -t` passes. Never stops or disables SSH.
- **packages**: removes `BAD_PKGS`, except `PROTECTED_PKGS`.
- **media**: lists media files and deletes ones inside Music, Downloads, or Videos folders (`MEDIA_DIRS`).
- **perms**: file permissions on account and password files.
- **groups**: group membership from `GroupMembers`. Reports README groups that don't exist.
- **forensics**: lists the "Forensics Question" files on the Desktop and reminds you to answer them. It does not answer them.
- **services**: reports whether the README's critical services are running. Stops and disables prohibited services (Telnet, FTP servers, TFTP, rsh, SNMP, NFS, rpcbind) unless the README names them as critical.
- **logging**: installs and turns on auditd, with rules for account, sudo, and SSH config changes.
- **malware**: report only. Lists files in temp folders, service files not from a package, `authorized_keys` files, and startup lines that download or open a shell. Full list in the run folder.
- **userfiles**: lists scripts, executables, and known hacking-tool names in the user folders. You pick which to remove (numbers, or `none`).
- **removepaths**: lists the folders in each user's Desktop, Documents, Downloads, Music, Videos, and Pictures. You pick which to delete.
- **review**: loose files at the top of `/`, programs running from user or temp folders, and listening ports. You pick what to remove or stop; ports are report only.
- **audit**: report only (accounts, sudo, open ports, cron, SUID files, and more).

Module order (`MODULES` in `cp_harden.sh`): accounts, system settings, services and packages, updates and malware, files, review, final check.

## Logs, backups, and summary

Each run creates `/root/cp-reports/run-<time>/` containing:
- `run.log`: every action with its result (`DRY`, `OK`, `WARN`, `FALLBACK`, `FAILED`)
- `transcript.txt`: everything printed on screen
- `summary.json`: counts and the list of failed actions
- `backup/`: copies of the files changed, saved before any change (even in a dry run)

Check the summary for `FAILED` lines. Those need a manual fix.

## Emergency stop

To halt before the next module:

```bash
sudo touch /root/cp-reports/STOP
```

Delete the file to run again.

## Safety checks

- Refuses to run without root.
- Refuses `--apply` if none of the listed admins exist on the machine.
- Refuses `--apply` over SSH if the change would cut off the session.
- Never stops or purges `openssh-server`, Chromium, or LightDM.
- Never deletes an account whose name appears anywhere in the README (case-insensitive). If the README can't be read, no unauthorized account is deleted. Those cases are reported as `SKIPPED`, so check them by hand.
- Name matching ignores case, so `Jpearson` in the README matches the `jpearson` account.
- Each change has a fallback command. If both fail, the run continues and logs `FAILED`.

## Restoring

Backups are in `/root/cp-reports/run-<time>/backup/`. Copy a file back with `sudo cp` to undo a single change. Account deletions can't be undone from this toolkit.

## Not covered

- Forensics question answers (answer them by hand)
- Competition-specific items the README asks for but the toolkit doesn't know about. Check those by hand.
- Anything that needs a human decision (which admins to keep, which services are required)

## Notes

- Test on a practice image before a real round. The scripts were written and checked for syntax, but not run against a live image.
- Check your team's competition rules for what can run on the image.
