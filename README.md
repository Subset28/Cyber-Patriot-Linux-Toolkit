# CyberPatriot Linux Toolkit (Mint / Ubuntu / Debian)

A guided hardening toolkit for CyberPatriot Linux images. It reads the competition README, saves backups,
runs one step at a time, and logs everything. **The default is a dry run: nothing changes until you choose APPLY.**

The toolkit is built around one rule: **it does not decide what your scenario needs. You do.** Software, services,
files, and folders are shown as numbered lists, and you pick what to remove. The one exception is user accounts
that are not on the README's lists: those are removed, as the Windows toolkit does, so check the list before you apply.

## What it reads from the competition README

Save the README as `.txt` or `.html` on the Desktop (`.md` works too). Launcher files like `.desktop` are skipped.

| README says | What the toolkit does with it |
|---|---|
| Authorized administrators and users | Removes other accounts and their home folders, demotes extra admins, **lists missing authorized accounts and you pick which to create** |
| All users need passwords | Every authorized account gets a generated 16-character password, saved to `new-passwords.txt` in the run folder. Passwords are not shown on screen |
| Critical services | Never stopped. The SSH service is hardened and restarted only after `sshd -t` passes |
| Software that must stay | Packages in `PROTECTED_PKGS` are never offered for removal |

## Quick start

Open a terminal and run the menu:

```bash
cd ~/cp-toolkit                    # or wherever you copied it
sudo bash cp_menu.sh
```

The menu has the same five options as the Windows Run-Menu:

1. **Start**: run every step on this PC. It asks before each step. Type `APPLY` to confirm the changes.
2. **Practice run**: the same steps, but nothing is changed. It still asks before each step.
3. **Show the last run's results** and any failed actions.
4. **Undo**: puts back the config files saved by the last run. Type `UNDO` to confirm.
5. **Quit**

Before each step the script asks `Run this step: <what it does>? (y/n)`. Type `y` or `n`. Enter does not answer.
A skipped step is skipped.

Without the menu:

```bash
sudo bash cp_harden.sh --show        # print users, admins, and services from the README
sudo bash cp_harden.sh               # practice run: every step, no prompts
sudo bash cp_harden.sh --ask         # practice run, asking before each step
sudo bash cp_harden.sh --apply --ask # make changes, asking before each step
sudo bash cp_harden.sh --results     # last run's results
sudo bash cp_harden.sh --undo        # put back the last run's config files
```

## Options

| Command | What it does |
|---|---|
| `sudo bash cp_harden.sh` | Practice run, all steps, pauses for Enter between steps |
| `sudo bash cp_harden.sh --apply` | Make changes, all steps |
| `sudo bash cp_harden.sh --ask` | Ask y/n before each step (practice run) |
| `sudo bash cp_harden.sh --no-pause` | Do not wait for Enter between steps |
| `sudo bash cp_harden.sh --only ssh,firewall` | Run only these steps |
| `sudo bash cp_harden.sh --skip media` | Run everything except these steps |
| `sudo bash cp_harden.sh --list` | Print step names, in order, and exit |
| `sudo bash cp_harden.sh --show` | Print the README's users, admins, and services, and exit |
| `sudo bash cp_harden.sh --results` | Print the last run's summary and failed actions, and exit |
| `sudo bash cp_harden.sh --undo` | Restore the config files saved by the last run, and exit |

Step names: `forensics`, `users`, `auth`, `groups`, `guest`, `ssh`, `sysctl`, `firewall`, `perms`, `logging`,
`services`, `packages`, `updates`, `malware`, `userfiles`, `media`, `removepaths`, `review`, `audit`.

## Configuration: config.env

Leave a line commented to let the README fill it in. Uncomment it to override.

| Setting | Meaning |
|---|---|
| `ADMINS`, `USERS`, `SERVICES` | Override what the README parser finds |
| `NEW_ADMINS` | New admin accounts to create (forced password change at login). If unset, you are asked. |
| `NewUsers` | Standard (non-admin) accounts to create, e.g. `NewUsers=("belethor")`. Gets a generated password. |
| `GroupMembers` | Add users to groups, for example `GroupMembers=("candace:firesidegirls")` |
| `DeleteUnauthorizedHomes` | `1` (default): delete a removed user's home folder too. Listed users' homes are never touched. |
| `ALLOW_TCP_PORTS` | Ports to open in UFW besides SSH |
| `PASS_MAX_DAYS`, `PASS_MIN_DAYS`, `PASS_WARN_AGE`, `PASS_MIN_LEN` | Password aging and length |
| `FAILLOCK_DENY`, `FAILLOCK_UNLOCK` | Account lockout threshold and time |
| `MEDIA_EXT` | File extensions treated as media |
| `MEDIA_DIRS` | Folder names where media is offered for deletion (default `music|downloads|videos`) |
| `BAD_PKGS` | Packages offered for removal when installed (includes FTP servers and ManaPlus, Game Conqueror) |
| `PROTECTED_PKGS` | Packages never offered for removal, even if listed in `BAD_PKGS` |

## What each step does

- **forensics**: lists the "Forensics Question" files on the Desktop. It runs first. Answer them by hand before anything else changes.
- **users**: removes accounts not on any list (skips the account you're logged in with), and removes admin rights from users who aren't authorized admins. Lists missing authorized accounts and you pick which to create. Creates `NEW_ADMINS` and `NewUsers`. Locks root.
- **auth**: password aging, password quality, lockout settings, and password history (`remember=5` in common-password).
- **groups**: group membership from `GroupMembers`. Reports README groups that don't exist.
- **guest**: turns off guest login on LightDM. Prints a note on other display managers.
- **ssh**: hardens `sshd` (no root login, no empty passwords) and restarts it only after `sshd -t` passes. Never stops or disables SSH.
- **sysctl**: network hardening settings in `/etc/sysctl.d/`.
- **firewall**: enables UFW, denies inbound by default, allows SSH and `ALLOW_TCP_PORTS`.
- **perms**: file permissions on account and password files.
- **logging**: installs and turns on auditd, with rules for account, sudo, and SSH config changes.
- **services**: reports whether the README's critical services are running. Lists prohibited services (Telnet, FTP servers, TFTP, rsh, SNMP, NFS, rpcbind) that are running or enabled, and you pick which to stop and disable. Services the README names as critical are never offered.
- **packages**: lists installed `BAD_PKGS`, and you pick which to remove. `PROTECTED_PKGS` are never offered.
- **updates**: full upgrade, automatic security updates.
- **malware**: report only. Lists files in temp folders, service files not from a package, `authorized_keys` files, and startup lines that download or open a shell. Full list in the run folder.
- **userfiles**: lists scripts, executables, and known hacking-tool names in the user folders. You pick which to remove.
- **media**: lists media files. Offers to delete the ones inside Music, Downloads, or Videos folders (`MEDIA_DIRS`), and you pick which.
- **removepaths**: lists the folders in each user's Desktop, Documents, Downloads, Music, Videos, and Pictures. You pick which to delete.
- **review**: loose files at the top of `/`, and programs running from user or temp folders. You pick what to remove or stop. Listening ports are report only.
- **audit**: report only (accounts, sudo, open ports, cron, SUID files, and more).

Step order is set by `MODULES` in `cp_harden.sh`. Forensics is first.

## Logs, backups, and results

Each run creates `/root/cp-reports/run-<time>/` containing:
- `run.log`: every action with its result (`DRY`, `OK`, `WARN`, `FALLBACK`, `FAILED`)
- `transcript.txt`: everything printed on screen
- `summary.json`: counts and the list of failed actions
- `new-passwords.txt`: generated passwords (plain text, so delete the run folder when practice is over)
- `backup/`: copies of the config files changed, saved before any change (even in a practice run)

Use `--results` or menu option 3 to see the last run's failed actions. Check them by hand.

## Undo

Menu option 4, or `sudo bash cp_harden.sh --undo`, copies back the config files the last run saved: `login.defs`,
the password quality and lockout files, `sshd_config` and its drop-ins, `sysctl.d`, `/etc/default/ufw`, and
`common-password`. It also removes the drop-ins the toolkit creates.

Undo does **not** restore accounts, passwords, removed packages, stopped services, deleted files or folders, or
UFW rules. Those need a hand fix. After undo, run `sudo sysctl --system`, and restart SSH if you changed it.

## Emergency stop

To halt before the next step:

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
- Removal steps are pick lists with `none` always available. Enter alone never answers.
- Each change has a fallback command. If both fail, the run continues and logs `FAILED`.

## Not covered yet

Things the Windows toolkit does that this one doesn't, yet:
- Warnings before risky settings (the Windows toolkit asks before SMB signing, NTLM, and similar)
- Automatic or manual choice for each step (the Windows toolkit has it for a few steps)
- Tests and a CI workflow (the Windows repo has Pester and PSScriptAnalyzer checks)
- A per-program "keep and update" list, and a store-app list

Also not covered:
- Forensics question answers (answer them by hand)
- Competition-specific items the README asks for but the toolkit doesn't know about. Check those by hand.
- Anything that needs a human decision (which admins to keep, which services are required)

## Notes

- Test on a practice image before a real round. The scripts have been checked for syntax and run in practice mode, but not run with `--apply` on a live image.
- Check your team's competition rules for what can run on the image.
