# GhostDeploy
Deploy a production-ready Ghost installation on Ubuntu

First version added. If you try it and it doesn't work, please create an issue.

This script is designed to take a new Ubuntu installation and do the following:
- Update (full dist-upgrade)
- Install latest Nginx, MySQL
- Generate MySQL password and create DB & user
- Install Node.js 16, latest Ghost CLI & latest Ghost
- Configure and enable UFW, leaving only ports 22, 443 and 80 open.
- Copy SSH keys from root user to the newly created Ghost user
- Disable root login via SSH
- save the created install log and config files as timestamped files in the GhostDeploy directory.

The script should be run as root, and it will reboot the server a couple of times. After the first reboot, it will continue where it left off. It will broadcast progress to your SSH shell, but you can also `cat / tail-f deploy.log` to see progress.

Notes:
- I created this for my own purposes, but have cleaned it up and will continue to do so to create a full installation stack for Ghost (see the rough road map below).
- If the username you enter already exists, it will skip creating it and it won't copy SSH keys from root to the new user.
- The script sets up autologin for root (to allow rebooting after fully patching), but removes it at the end. It also enables passwordless sudo for the Ghost, but also removes this at the end.
- I'm completely open to any suggestions on improving this (add an issue or submit a PR).

## Download

```
git clone https://github.com/techbitsio/GhostDeploy
```

## Basic usage

```
cd GhostDeploy
./deploy.sh
```

## Advanced usage

If you're going to restore an existing Ghost install/database, you can pass in the previous SQL credentials for the new SQL setup:

```
./deploy.sh -d dbname -u dbuser -p dbuserpass
```

Stage 1: script will install necessary components on a clean Ubuntu installation, resulting in a fully-updated system, running the latest version of Ghost.

Stage 2: Backup component. Setup up regular backups of content, database and config file. Ability to deploy Ghost using an existing backup. Backup component will be able to run on any self-hosted Ghost installation, not just those created by this tool.

Stage 3: WAF (ModSecurity) component. Install ModSec and ruleset. Applicable to any Nginx web server.

Stage 4: Varnish caching component. Install and configure Varnish. Applicable to any self-hosted Ghost installation.

Stages 2, 3 & 4 will be separate repositories.
