# ssh-notify

Get an email when somebody connects to ssh.
This script is called by `sshrc` file and send an email notification every time
somebody make a successful connection by SSH.

## How it works
**ssh-notify** writes an entry in a log file every time someone make a successful
connection by SSH then it sends an email.
In the config file, you can set a period of time to avoid receiving multiple times the same email.
For example, if the last connection is less than 1 hour, you will not reveive another email.

**ssh-notify** uses `logger` and `journactl` commands to read/write the log,
but you can use a custom log file if you have access issues.
If you want to secure writes inside the logs, you can also run ssh-notify in sudo mode.
In this case, you have to add SSH users in ssh-notify sudoers group.

## Requirements
- `bash`
- `sendmail`
- Optionnal: `sudo`

## Install
Download and install the last version of the deb package here: https://github.com/pruje/ssh-notify/releases

## Manual install
1. Clone this repository: `git clone https://github.com/pruje/ssh-notify`
2. Update submodules: `git submodule update --init`
3. Run `./ssh-notify.sh --install`

## Uninstall
Uninstall the deb package or run `./ssh-notify.sh --uninstall`.

## License
ssh-notify is licensed under the MIT License. See [LICENSE.md](LICENSE.md) for the full license text.

## Credits
Author: Jean Prunneaux https://jean.prunneaux.com

Source code: https://github.com/pruje/ssh-notify

Report a bug or request for a feature [here](https://github.com/pruje/ssh-notify/issues).
