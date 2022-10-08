#!/bin/bash

### https://github.com/techbitsio/GhostDeploy
### Version 0.0.1

# Find directory file is running from and cd to it
run_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd $run_dir

# Set deploy log location
step_log=$run_dir/deploy.log



while getopts ":e:d:u:p:n:" flag; do
                case ${flag} in
                 e  ) email=${OPTARG}
                    echo "email=$email" >> deploy.config
                    ;;
		 d  ) dbname=${OPTARG}
		    echo "dbname=$dbname" >> deploy.config
		    ;;
		 u  ) dbuser=${OPTARG}
		    echo "dbuser=$dbuser" >> deploy.config
		    ;;
		 p  ) dbpass=${OPTARG}
		    echo "dbpass=$dbpass" >> deploy.config
		    ;;
		 n  ) nonint=${OPTARG}
		    ;;
                esac
        done





# Create deploy log if necessary and add initial message. Or resume deployment and add message.
if [ ! -f "$step_log" ]; then
        touch $step_log
        echo -e "Created $step_log at $(date +"%Y-%m-%d %T")\nBeginning deployment..." >> $step_log
        #echo starting message with date time etc.
else
        #file exists. resuming at date time etc.
        if [ -s $step_log ]; then
                echo -e "Resuming deployment. Let's see... where did we leave off? [$(date +"%Y-%m-%d %T")]" >> $step_log
        else
                echo -e "Hmmm... deploy log is empty. I'll guess we'll start at the beginning... [$(date +"%Y-%m-%d %T")]" >> $step_log
        fi
fi

# Logging function. Used to track steps already completed, and for user information.
log() {
	if [ ! -v $nonint ]; then
		wall -n $1
	fi
        echo $(date +"%Y-%m-%d %T") :: $1 >> $step_log        
}

# Script checks deploy log to see if currently step has already run
check_step() {
        step=$1
        if grep -Fq "$step complete" $step_log; then
        #if [ ! -f "$step_file" ]; then
                echo "Step $step skipped"
                return 1
        else
                log "$step starting"
        fi
}

# Script adds to deploy log once step is complete
step_done() {
        step=$1
        log "$step complete"
}

# Run function: to run check_step, step_done and actual step
run() {
        if [ -z "$2" ]; then
            check_step $1 && $1 && step_done $1
        else
            check_step $1 && $1 $2 && step_done $1
        fi
}





######################
### STEP FUNCTIONS ###
######################

# Create empty config file
create_config() {
    touch deploy.config
}

# Create service to automatically log root user back in following a reboot, and restart the script.
# 1) Yes, logging root isn't the best idea. The removal service does undo this however.
# 2) We set the script running on login using root's profile, but not for SSH instances (prevent multiple triggers)
create_the_service() {
	mkdir /etc/systemd/system/getty@tty1.service.d/
	touch /etc/systemd/system/getty@tty1.service.d/override.conf
	echo "[Service]" >> /etc/systemd/system/getty@tty1.service.d/override.conf
	echo "ExecStart=" >> /etc/systemd/system/getty@tty1.service.d/override.conf
	echo "ExecStart=-/sbin/agetty --noissue --autologin root %I $TERM" >> /etc/systemd/system/getty@tty1.service.d/override.conf
	echo "Type=idle" >> /etc/systemd/system/getty@tty1.service.d/override.conf
	
	echo '[ -z "$SSH_TTY" ] && '"${0} -n yes" >> /root/.profile
}

# Cleanup: remove the service
# Undoing the root auto-login, and profile
remove_the_service() {
	sed -i "\|${0}|d" /root/.profile
	
	rm /etc/systemd/system/getty@tty1.service.d/override.conf
	rmdir /etc/systemd/system/getty@tty1.service.d/
}

do_update() {
    apt-get update
}

# Upgrade everything
do_upgrade() {
	DEBIAN_FRONTEND=noninteractive \
	apt-get \
	-o Dpkg::Options::="--force-confnew" \
	--allow-downgrades --allow-remove-essential --allow-change-held-packages \
	-fuy \
	dist-upgrade
}

# Add site directory and set permissions/ownership
add_site_dir() {
	mkdir -p /var/www/$domain
	chown $username:$username /var/www/$domain
	chmod 755 /var/www/$domain
}

#nginx_config() {
#	#replace gzip on with gzip on PLUS additional compression details
#	sed -i 's/gzip on;/gzip on;\n\n\tgzip_vary on;\n\tgzip_min_length #10240;\n\tgzip_proxied expired no-cache no-store private auth;\n\tgzip_types #text\/plain text\/css text\/xml text\/javascript application\/x-javascript #application\/xml;\n\tgzip_disable "MSIE [1-6]\.";\n/' /etc/nginx/nginx.conf
#}

#### notes remove: apt-get install apache2-utils for pass hashign
#### htpasswd -bnBC 10 "" passpasspasspass | tr -d ':\n'

### UPDATE users SET password='$2y$10$7E7id0pGy3pv1INTnN6emer70B.kOcPMTLB0fEpMHTUqnNwBSoWiK' WHERE email='ghost@example.com';

## ? allow running script with args?

# Pass parameters if set
pass_params() {
        while getopts ":e:d:u:p:n:" flag; do
                case ${flag} in
                 e  ) email=${OPTARG}
                    echo "email=$email" >> deploy.config
                    ;;
		 d  ) dbname=${OPTARG}
		    echo "dbname=$dbname" >> deploy.config
		    ;;
		 u  ) dbuser=${OPTARG}
		    echo "dbuser=$dbuser" >> deploy.config
		    ;;
		 p  ) dbpass=${OPTARG}
		    echo "dbpass=$dbpass" >> deploy.config
		    ;;
		 n  ) nonint=${OPTARG}
		    ;;
                esac
        done

}



# Add normal system user, add to sudoers, temporarily allow sudo without password
# Another one on the growing list of 'not good ideas'...
# 1) Ghost install needs to run as non-root user, and as sudo.
# 2) We remove this in a following step

add_user() {

    # see if username was NOT set using parameter
	if [ -z "$username" ]; then
		echo "New username:"
		read username 
		echo "username=$username" >> deploy.config
	else
		echo "Adding user: $username"
	fi

    # check if user already exists
    if id "$username" >/dev/null 2>&1; then
        echo "user ($username) already exists. Skipping."
    else
        adduser --gecos "" $username
        rsync --archive --chown=$username:$username /root/.ssh /home/$username
    fi
	
	usermod -aG sudo $username
	echo "$username ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

# Remove the passwordless sudo permission from our user. Sudo remains.
user_tidy() {
	sed -i "s/$username ALL=(ALL) NOPASSWD: ALL//" /etc/sudoers
}

# Questions to which we need answers
# *) We check against a variable in case the user has set via script parameters
# *) If we require a proper answer, we prompt the user
# *) Otherwise, we set a default/generate a password, etc.

## TODO: add question for staging. i.e. dev as far as ghost is concerned, and staging for letsencrypt 
config_questions() {
	if [ -z "$domain" ]; then
		echo "Domain (e.g. domain.com or sub.domain.com) ="
		read domain
		echo "domain=$domain" >> deploy.config
	fi

	if [ -z "$email" ]; then
		echo "Enter email address:"
		read email
		echo "email=$email" >> deploy.config
	fi

	if [ -z "$dbuser" ]; then
		dbuser=ghostdbuser
		echo "dbuser=$dbuser" >> deploy.config
	fi

	if [ -z "$dbpass" ]; then

		dbpass=$(date +%s | sha256sum | base64 | head -c 32 ; echo)
		echo "dbpass=$dbpass" >> deploy.config
	fi

	if [ -z "$dbname" ]; then
		dbname=ghost_db_prod
		echo "dbname=$dbname" >> deploy.config
	fi

}

kernel_reboot_hints_disable() {
    sed -i 's/#$nrconf{kernelhints} = -1;/$nrconf{kernelhints} = 0;/' /etc/needrestart/needrestart.conf
}

# Install Nginx, set firewall rules
install_nginx() {
	apt-get install nginx -y
	ufw allow 'Nginx Full'
}

# Set SSH firewall rules
ssh_firewall() {
    ufw allow ssh
}

# Enable UFW Firewall
enable_firewall() {
    ufw --force enable
}

# Install MySQL server
install_mysql() {
	apt-get install mysql-server -y
}

# Configure MySQL using generated or provided credentials
config_mysql() {
	mysql -u root -e "CREATE USER "$dbuser"@"localhost" IDENTIFIED BY "\"$dbpass"\";"
	mysql -u root -e "CREATE DATABASE $dbname;"
	mysql -u root -e "GRANT ALL ON $dbname.* TO $dbuser@localhost;"
	mysql -u root -e "FLUSH PRIVILEGES;"
}

# Install Node - Ghost currently requires, among others, version 16
install_node() {
	curl -sL https://deb.nodesource.com/setup_16.x | bash
	apt-get install nodejs -y
	npm install ghost-cli@latest -g
}

# Install Ghost
ghost_install() {
	su $username -c "ghost install --dir "/var/www/$domain" --sslemail $email --url $domain --dbhost localhost --dbuser $dbuser --dbpass $dbpass --dbname $dbname --auto --start --enable --no-prompt"
}

# Disable root login via SSH
disable_root_ssh() {
    sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
}

# Delayed reboot
delayed_reboot() {
	( sleep 10 ; reboot ) &
}

# Rename the config and log files
rename_log_config_files() {
	
	date_var=$(date '+%Y%m%d-%H%M%S')
	mv $step_log $run_dir/deploy-$date_var-$domain.log
	
	mv $run_dir/deploy.config $run_dir/deploy-$date_var-$domain.config
	step_log=$run_dir/deploy-$date_var-$domain.log
}

run create_config

run add_user
run config_questions
run kernel_reboot_hints_disable
run do_update
run do_upgrade
run create_the_service
check_step reboot1 && reboot && step_done reboot1
. $run_dir/deploy.config

run install_nginx
run ssh_firewall
run enable_firewall
run add_site_dir

run install_mysql
run config_mysql
run install_node
run ghost_install

run user_tidy
run remove_the_service
run disable_root_ssh
run delayed_reboot
run rename_log_config_files
