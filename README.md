This is a fork to remove unnecessary dependencies and do other cleanups.  
- use `read` to read a file (buit-in, no child proc `$(...)`, no external `xargs`)
- use `select` to choose an item from a list (built-in, no need to make user re-run etc)
- replace many unnecessary `foo=$(echo foo |grep ... |bla ...)`
- no longer uses grep or awk or tail or xargs or any external utils that bash can do itself
- don't run the whole script as root, script calls sudo (or other) itself just where needed
- configurable http client (wget, curl, aria2c, others...)
- configurable sudo-alike (sudo, pkexec, lxsudo, others...)
- config bits gathered at the top
- download files to tmp, use trap to delete on exit
- specify /dev/nvme0 on command line
- lots of sanity/safety checks
- error / usage messages
- debug mode (DEBUG=true) that prints more messages and doesn't delete the temp files on exit

# WD SSD Firmware Updater for Debian-based Linux

This script updates Western Digital (WD) SSD firmware on debian-based systems.  
(Actually the only debianic part is automatically calling `apt install`  
if nvme-cli isn't installed. Other than that it's the same for any linux.)

It was initially developed for frame.work 13 laptops, but can be used for other devices as well.

See the discussion on: https://community.frame.work/t/western-digital-drive-update-guide-without-windows-wd-dashboard/20616

**Important Notes:**
- Firmware updates can be risky. Always back up your data and understand the risks before proceeding.
- Use at your own risk.

## Usage

`$ wd_ssd_fw_update.sh /dev/nvme0`

or verbose mode:

`$ DEBUG=true wd_ssd_fw_update.sh /dev/nvme0`


```
$ ./wd_ssd_fw_update.sh /dev/nvme0
./wd_ssd_fw_update.sh - WD nvme drive firmware updater
Device:   /dev/nvme0
Model:    WDS200T1X0E-00AFY0
Firmware: 614900WD

Available 613200WD is not newer.

Update(s) available:
1) 615400WD
Which version do you want to install (1-1)? 1

Load 615400WD.fluf onto /dev/nvme0 (y/N)? y
[sudo] password for bkw: 
Firmware download success

Activate the new firmware (y/N)? y
Success committing firmware action:3 slot:2
identify-ctrl: Success

Firmware update process completed. Please reboot.

$ 

```


```
$ ./wd_ssd_fw_update.sh /dev/nvme0
./wd_ssd_fw_update.sh - WD nvme drive firmware updater
Device:   /dev/nvme0
Model:    WDS200T1X0E-00AFY0
Firmware: 615400WD

Available 613200WD is not newer.
Available 615400WD is not newer.

No updates available.
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
| Brian K. White     | @bkw777         | rewrite         |
