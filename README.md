This is a fork to remove unnecessary dependencies and do other cleanups.  
- original claims to need mawk but really only uses any kind of awk
- but actually, does not need any awk at all, it's only using awk for a things that are doable right in bash
- use `read` to read a file (buit-in, no child proc `$(...)`, no external `xargs`)
- use `select` to choose an item from a list (built-in, no need to make user re-run etc)
- replace many unnecessary `foo=$(echo foo |grep ... |bla ...)`
- no longer uses grep or awk or tail or xargs or any external utils that bash can do itself
- don't run the whole script as root, script calls sudo (or other) just where needed
- configurable http client (wget, curl, aria2c, others...)
- configurable sudo-alike (sudo, pkexec, lxsudo, others...)
- config bits gathered at the top
- download files to tmp, use trap delete on exit

# WD SSD Firmware Updater for Debian-based Linux

This script updates Western Digital (WD) SSD firmware on debian-based systems.  
(Actually the only debianic part is automatically calling `apt install`  
if nvme-cli isn't installed. Other than that it's the same for any linux.)

It was initially developed for frame.work 13 laptops, but can be used for other devices as well.

See the discussion on: https://community.frame.work/t/western-digital-drive-update-guide-without-windows-wd-dashboard/20616

**Important Notes:**
- This script only updates if the current firmware version is directly supported.
- Firmware updates can be risky. Always back up your data and understand the risks before proceeding.
- Use at your own risk.

## Usage

0. Download `wd_ssd_fw_update.sh` from this repo.
1. Ensure the SSD is located at `/dev/nvme0` or modify the script accordingly.
3. Run the script: `$ ./wd_ssd_fw_update_ssh.sh`

```
$ ./wd_ssd_fw_update.sh
./wd_ssd_fw_update.sh - WD nvme drive firmware updater

Updating firmware for /dev/nvme0

Model: WDS200T1X0E-00AFY0
Firmware: 614900WD

Found the following firmware versions available for your drive:
613200WD 615400WD

1) 613200WD
2) 615400WD
Select version to install: 2

Firmware File: 615400WD.fluf
Dependencies:
614300WD 614600WD 614900WD 615100WD 615300WD

Downloading https://wddashboarddownloads.wdc.com/wdDashboard/firmware/WDS200T1X0E-00AFY0/615400WD/615400WD.fluf ...

Load 615400WD.fluf onto /dev/nvme0 (y/N)? y
[sudo] password for bkw: 
Firmware download success

Activate the new firmware (y/N)? y
Success committing firmware action:3 slot:2
identify-ctrl: Success

Firmware update process completed. Please reboot.

$ 
```

## Requirements

- `bash`
- `wget` or `curl` or `aria2c` or other
- `sudo` or `pkexec` or other
- `nvme-cli`

## Contributors

| Contributor        | GitHub Handle   | Contributions   |
| ------------------ | --------------- | --------------- |
| Jules Kreuer       | @not_a_feature  | Author          |
| Klaas Demter       | @Klaas-         | Adaptations     |
| Edward Felder      |                 | Initial idea    |
| Oleksandr Lutai    |                 | Initial idea    |
| Brian K. White     | @bkw777         | refactor        |
