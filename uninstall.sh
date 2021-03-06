#!/bin/bash
#
#  ssh-notify uninstall script
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh - &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "internal error"
	exit 1
fi

if [ "$lb_current_user" != root ] ; then
	lb_error "You must be root to uninstall ssh-notify"
	exit 1
fi

# edit sshrc
if [ -f /etc/ssh/sshrc ] ; then
	if ! lb_edit '/ssh-notify/d' /etc/ssh/sshrc ; then
		lb_error "sshrc cannot be changed"
		lb_exitcode=3
	fi
fi

# delete sudoers file
if ! rm -f /etc/sudoers.d/ssh-notify ; then
	lb_error "sudoers file cannot be deleted"
	lb_exitcode=3
fi

lb_exit
