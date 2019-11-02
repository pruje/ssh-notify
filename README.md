# ssh-notify

Get an email when somebody connects to ssh.
This script is called by `sshrc` file and send an email notification every time
somebody make a successful connection by SSH.

## How it works
**ssh-notify** writes an entry in a log file every time someone make a successful
connection by SSH then it sends an email.
In the config file, you can set a period of time to avoid receiving multiple times the same email.
For example, if the last connection is less than 1 hour, you will not reveive another email.

## Requirements
- `bash`
- `sendmail`

## Install
### Debian/Ubuntu package
1. Download the last version of [ssh-notify here](https://github.com/pruje/ssh-notify/releases)
2. Run `dpkg -i ssh-notify-X.X.X.deb`

### Manual install
1. Clone this repository: `git clone https://github.com/pruje/ssh-notify`
2. Update submodules: `git submodule update --init`
3. Run `install.sh`

## Configuration
1. Edit `/etc/ssh/ssh-notify.conf`
2. Add all users you want to monitor in `ssh-notify` group
3. (optionnal) If you want to secure access to the log file, you can enable the sudo mode in config
then add the following line in `/etc/sudoers.d/ssh-notify`:
```
%ssh-notify ALL = NOPASSWD:/path/to/ssh-notify/ssh-notify.sh
```

## Uninstall
### Debian/Ubuntu package
Run `apt remove ssh-notify`

### Manual install
Run `uninstall.sh`

## License
ssh-notify is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for the full license text.

## Credits
Author: Jean Prunneaux https://jean.prunneaux.com

Source code: https://github.com/pruje/ssh-notify

Report a bug or request for a feature [here](https://github.com/pruje/ssh-notify/issues).
