# WD NVME Firmware Updater

Updates the firmware of a Western Digital nvme ssd on Linux.

[Initially developed for frame.work laptops](https://community.frame.work/t/western-digital-drive-update-guide-without-windows-wd-dashboard/20616), but can be used for other devices as well.

**Firmware updates are always risky. Use at your own risk.**

## Usage

`$ ./wd_nvme_update.sh`  
or  
`$ ./wd_nvme_update.sh /dev/nvme1`  
or  
`$ DEBUG=true ./wd_nvme_update.sh`


```
$ ./wd_nvme_update.sh
./wd_nvme_update.sh - WD nvme drive firmware updater
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
$ ./wd_nvme_update.sh
./wd_nvme_update.sh - WD nvme drive firmware updater
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

## Fork
This was forked from https://github.com/not-a-feature/wd_ssd_firmware_update to remove unnecessary dependencies and do other cleanups.  
- use built-in `read` to read a file directly instead of a child shell and external executable
- use built-in `select` to choose an item from a list
- replace many unnecessary `foo=$(echo foo |grep ... |bla ...)`
- no longer uses grep or awk or tail or xargs or any external utils that bash can do itself
- don't run the whole script as root, the script calls sudo (or other) itself just where needed
- configurable list of http clients (wget, curl, aria2c, etc) scanned and selected automatically
- configurable list of sudo-likes (sudo, pkexec, exit) scanned and selected automatically
- configurable list of package managers (apt, dnf, zypper, pacman, etc) scanned and selected automatically
- config bits gathered at the top
- download files to tmp, use trap to delete on exit
- optionally specify /dev/nvme# on command line instead of default /dev/nvme0
- more sanity/safety checks
- error / usage messages
- debug mode that prints more messages and doesn't delete the temp files on exit
- removed ubuntu/mint/apt assumptions, should work on any distribution
