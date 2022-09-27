# GhostDeploy
Deploy a production-ready Ghost installation on Ubuntu

Not much to see here yet.

Stage 1: script will install necessary components on a clean Ubuntu installation, resulting in a fully-updated system, running the latest version of Ghost.

Stage 2: Backup component. Setup up regular backups of content, database and config file. Ability to deploy Ghost using an existing backup. Backup component will be able to run on any self-hosted Ghost installation, not just those created by this tool.

Stage 3: WAF (ModSecurity) component. Install ModSec and ruleset. Applicable to any Nginx web server.

Stage 4: Varnish caching component. Install and configure Varnish. Applicable to any self-hosted Ghost installation.

Stages 2, 3 & 4 will be separate repositories.
