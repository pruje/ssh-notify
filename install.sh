#!/bin/bash
#
#  ssh-notify install script
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh - &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "internal error"
	exit 1
fi

if [ "$lb_current_user" != root ] ; then
	lb_error "You must be root to install ssh-notify"
	exit 1
fi

mkdir -p /etc/ssh || exit 1

# create config file if not exists
if ! [ -f /etc/ssh/ssh-notify.conf ] ; then
	cp "$lb_current_script_directory"/ssh-notify.conf /etc/ssh/ssh-notify.conf || exit 1
fi

# create sshrc
if ! [ -f /etc/ssh/sshrc ] ; then
	touch /etc/ssh/sshrc && chown root:root /etc/ssh/sshrc && chmod 755 /etc/ssh/sshrc
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

# if no force mode
if [ "$1" != "-f" ] ; then
	echo "WARNING:"
	echo "If your users cannot use logger and journalctl commands, you can enable"
	echo "the sudo mode."
	echo "In this case, please be sure that this script is owned by root and cannot be modified by anyone,"
	echo "because sudoers will be able to run it without password."

	lb_yesno "Do you want to enable sudoers to run this script?" || return 0
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
	lb_error "sudoers file cannot be modified"
	exit 1
fi

echo "[INFO] Add all authorized SSH users in the ssh-notify group if you want to enable sudo mode."
