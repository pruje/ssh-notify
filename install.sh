#!/bin/bash
#
#  ssh-notify install script
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#

curdir=$(dirname "$0")

# load libbash
source "$curdir"/libbash/libbash.sh - &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "internal error"
	exit 1
fi

if [ "$lb_current_user" != root ] ; then
	lb_error "You must be root to install ssh-notify"
	exit 1
fi

# secure files
chown -R root:root "$curdir"
chmod -R 755 "$curdir"
chmod -x "$curdir"/*.md "$curdir"/*.conf "$curdir"/emails/* \
         "$curdir"/libbash/*.* "$curdir"/libbash/*/*

# create config file if not exists
if ! [ -f /etc/ssh/ssh-notify.conf ] ; then
	mkdir -p /etc/ssh && \
	cp "$curdir"/ssh-notify.conf /etc/ssh/ssh-notify.conf
	if [ $? != 0 ] ; then
		lb_error "Cannot create config file"
		exit 3
	fi
fi

# create ssh-notify group if not exists
if ! grep -q '^ssh-notify:' /etc/group ; then
	addgroup ssh-notify
	if [ $? != 0 ] ; then
		lb_error "Cannot create group ssh-notify"
		exit 3
	fi
fi

# secure config
chown root:ssh-notify /etc/ssh/ssh-notify.conf && \
chmod 640 /etc/ssh/ssh-notify.conf

# secure default log file
touch /var/log/ssh-notify.log && \
chown root:ssh-notify /var/log/ssh-notify.log && \
chmod 660 /var/log/ssh-notify.log

# create sshrc
if ! [ -f /etc/ssh/sshrc ] ; then
	touch /etc/ssh/sshrc && \
	chown root:root /etc/ssh/sshrc && chmod 755 /etc/ssh/sshrc
	if [ $? != 0 ] ; then
		lb_error "Cannot create sshrc file"
		exit 3
	fi
fi

# edit sshrc
if ! grep -q ssh-notify /etc/ssh/sshrc ; then
	echo "$lb_current_script_directory/ssh-notify.sh &" >> /etc/ssh/sshrc
	if [ $? != 0 ] ; then
		lb_error "sshrc cannot be modified"
		exit 3
	fi
fi

echo "[INFO] Add all authorized SSH users in the ssh-notify group."
