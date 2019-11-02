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
		exit 1
	fi
fi

# secure config
chown root:ssh-notify /etc/ssh/ssh-notify.conf
chmod 640 /etc/ssh/ssh-notify

# create sshrc
if ! [ -f /etc/ssh/sshrc ] ; then
	touch /etc/ssh/sshrc && \
	chown root:root /etc/ssh/sshrc && chmod 755 /etc/ssh/sshrc
	if [ $? != 0 ] ; then
		lb_error "Cannot create sshrc file"
		exit 1
	fi
fi

# edit sshrc
if ! grep -q ssh-notify /etc/ssh/sshrc ; then
	echo "$lb_current_script_directory/ssh-notify.sh &" >> /etc/ssh/sshrc
	if [ $? != 0 ] ; then
		lb_error "sshrc cannot be modified"
		exit 1
	fi
fi

# create ssh-notify group if not exists
if ! grep -q '^ssh-notify:' /etc/group ; then
	addgroup ssh-notify
	if [ $? != 0 ] ; then
		lb_error "Cannot create group ssh-notify"
		exit 1
	fi
fi

# create sudoers file
mkdir -p /etc/sudoers.d && touch /etc/sudoers.d/ssh-notify && \
chown root:root /etc/sudoers.d/ssh-notify	&& chmod 640 /etc/sudoers.d/ssh-notify && \
echo "%ssh-notify ALL = NOPASSWD:$lb_current_script_directory/ssh-notify.sh" > /etc/sudoers.d/ssh-notify
if [ $? != 0 ] ; then
	lb_error "Cannot edit sudoers."
	exit 1
fi

echo "[INFO] Add all authorized SSH users in the ssh-notify group."
