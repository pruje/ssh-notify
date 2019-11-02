#!/bin/bash
#
#  ssh-notify uninstall script
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
	lb_error "You must be root to uninstall ssh-notify"
	exit 1
fi

# edit sshrc
if [ -f /etc/ssh/sshrc ] ; then
	lb_edit '/ssh-notify/d' /etc/ssh/sshrc || lb_error "sshrc cannot be changed"
fi

# delete sudoers file
rm -f /etc/sudoers.d/ssh-notify || lb_error "sudoers file cannot be deleted"
