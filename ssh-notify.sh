#!/bin/bash

########################################################
#                                                      #
#  ssh-notify                                          #
#  A script to send notifications when somebody        #
#  made a connection in SSH.                           #
#                                                      #
#  MIT License                                         #
#  Copyright (c) 2017-2019 Jean Prunneaux              #
#  Website: https://github.com/pruje/ssh-notify        #
#                                                      #
#  Version 1.0.0-beta.2 (2019-04-09)                   #
#                                                      #
########################################################

#
#  Initialization
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "ssh-notify: cannot load libbash"
	exit 1
fi


#
#  Default config
#

config_file=/etc/ssh/ssh-notify.conf
templates=$lb_current_script_directory/emails
email_template=default
logger=true
log_date_format="%b %d %H:%M:%S"


#
#  Functions
#

# Print help
# Usage: print_help
print_help() {
	echo "Usage: $0 [OPTIONS] IP_SOURCE [USER]"
	echo
	echo "Options:"
	echo "  -c, --config PATH  Specify a config file (default /etc/ssh/ssh-notify.conf)"
	echo "  -i, --install      Run install process"
	echo "  -u, --uninstall    Run uninstall process"
	echo "  -h, --help         Print this help"
}


# Read log file
# Usage: read_log FILTER
read_log() {
	if lb_istrue $journalctl ; then
		journalctl -g "$*" 2> /dev/null
	else
		grep "$*" "$log_file" 2> /dev/null
	fi
}


# Get timestamp from a log line
# Usage: get_timestamp LINE
get_timestamp() {
	local -i spaces
	local i d date t

	spaces=$(echo -n "$log_date_format" | tr -cd '[[:space:]]' | wc -c)
	spaces+=1

	# get date from line
	d=$(echo "$*" | awk "{for(i=1;i<=$spaces;++i) print \$i}")

	# get real date
	date=$(date -d "$d" '+%Y-%m-%d %H:%M:%S %Z')

	for ((i=1; i<=2; i++)) ; do
		t=$(lb_date2timestamp "$date")

		# date is ok
		[ "$t" -le "$now" ] && break

		# date > now: decrement for 1 year
		date=$(date -d "$date -1 year")
	done

	echo $t
}


# Write something in log file
# Usage: write_log TEXT
write_log() {
	# no log: quit
	$log || return 0

	if lb_istrue $logger ; then
		logger "ssh-notify: $*"
	else
		mkdir -p "$(dirname "$log_file")" && \
		echo "$(lb_timestamp2date -f "$log_date_format" $now) $hostname $(whoami): ssh-notify: $*" >> "$log_file"
	fi
}


# Write an error message in logs
# Usage: write_log_error TEXT
write_log_error() {
	if $log ; then
		write_log "[error] $*"
	else
		lb_error "ssh-notify: $*"
	fi
}


# Put content in an email template
# Usage: replace_content FILE
replace_content() {
	sed "s/{{email_from}}/$email_sender/g;
		s/{{email_to}}/$email_monitoring/g;
		s/{{user}}/$user/g; s/{{hostname}}/$hostname/g;
		s/{{ip_source}}/$ip_source/g; s/{{date}}/$(lb_timestamp2date $now)/g" "$1"
}


# Install procedure
# Usage: install
install() {
	if [ "$(whoami)" != root ] ; then
		lb_error "You must be root to install ssh-notify"
		exit 1
	fi

	mkdir -p /etc/ssh || exit 1

	# create config file
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
		echo "$lb_current_script \"\$SSH_CONNECTION\" \"\$USER\" &" >> /etc/ssh/sshrc
		if [ $? != 0 ] ; then
			lb_error "sshrc cannot be modified"
			exit 1
		fi
	fi

	echo "WARNING:"
	echo "If your users cannot use logger and journalctl commands, you can enable"
	echo "the sudo mode."
	echo "In this case, please be sure that this script is owned by root and cannot be modified by anyone,"
	echo "because sudoers will be able to run it without password."
	lb_yesno "Do you want to enable sudoers to run this script?" || exit

	# create ssh-notify group
	groupadd -f ssh-notify
	if [ $? != 0 ] ; then
		lb_error "Cannot create group ssh-notify"
		exit 1
	fi

	# create sudoers file
	mkdir -p /etc/sudoers.d && touch /etc/sudoers.d/ssh-notify && \
	chown root:root /etc/sudoers.d/ssh-notify	&& chmod 640 /etc/sudoers.d/ssh-notify && \
	echo "%ssh-notify ALL = NOPASSWD:$lb_current_script" > /etc/sudoers.d/ssh-notify
	if [ $? != 0 ] ; then
		lb_error "sudoers file cannot be modified"
		exit 1
	fi
}


# Uninstall procedure
# Usage: uninstall
uninstall() {
	if [ "$(whoami)" != root ] ; then
		lb_error "You must be root to uninstall ssh-notify"
		exit 1
	fi

	# edit sshrc
	if [ -f /etc/ssh/sshrc ] ; then
		lb_edit '/ssh-notify/d' /etc/ssh/sshrc || lb_error "sshrc cannot be changed"
	fi

	# delete sudoers file
	rm -f /etc/sudoers.d/ssh-notify || lb_error "sudoers file cannot be deleted"
}


#
#  Main program
#

# get options
while [ $# -gt 0 ] ; do
	case $1 in
		-c|--config)
			config_file=$2
			shift
			;;
		-i|--install)
			install
			exit $?
			;;
		-u|--uninstall)
			uninstall
			exit $?
			;;
		-h|--help)
			print_help
			exit
			;;
		*)
			break
			;;
	esac
	shift
done

# get IP source (ignore aliases)
ip_source=$(echo $1 | awk '{print $1}')

user=$(whoami)
# get custom user
[ -n "$2" ] && user=$2

# get current timestamp
now=$(date +%s)

# load config
if ! lb_import_config "$config_file" ; then
	lb_error "ssh-notify: cannot load config file"
	exit 1
fi

# sudo mode: rerun script
if lb_istrue $sudo_mode && [ "$(whoami)" != root ] ; then
	# test if user is part of ssh-notify group
	if groups $user 2> /dev/null | grep -wq ssh-notify ; then
		sudo "$0" "$1" $user
		exit $?
	else
		exit 1
	fi
fi

# test config
if ! lb_is_integer $notify_frequency ; then
	# reset to default & continue
	notify_frequency=60
fi

# check user whitelist: do not continue
if [ ${#user_whitelist[@]} -gt 0 ] ; then
	lb_array_contains $user "${user_whitelist[@]}" && exit
fi

# check ip whitelist: do not continue
if [ ${#ip_whitelist[@]} -gt 0 ] ; then
	lb_array_contains $ip_source "${ip_whitelist[@]}" && exit
fi

if [ -z "$email_destination" ] ; then
	lb_error "ssh-notify: email recipient not set"
	exit 1
fi

notify=true
log=true

# notify everytime: do not use logs
if [ "$notify_frequency" == 0 ] ; then
	log=false
else
	# set log file
	if [ -z "$log_file" ] ; then
		# search default log file
		for f in /var/log/syslog /var/log/messages ; do
			[ -f "$f" ] && log_file=$f
		done

		if [ -z "$log_file" ] ; then
			lb_error "ssh-notify: log file not found"
			log=false
		fi
	fi
fi

if $log ; then
	# test logger and journalctl commands
	if lb_istrue $logger ; then
		if lb_command_exists logger ; then
			# test journalctl
			if lb_command_exists journalctl && journalctl -n 1 &> /dev/null ; then
				journalctl=true
			fi
		else
			logger=false
		fi
	fi

	# set log file for writing
	if ! lb_istrue $logger ; then
		if ! lb_set_logfile -a "$log_file" ; then
			lb_error "ssh-notify: log file not writable"
			log=false
		fi
	fi

	# test if log file is readable
	if ! lb_istrue $journalctl ; then
		if ! [ -r "$log_file" ] ; then
			lb_error "ssh-notify: log file not readable"
			log=false
		fi
	fi
fi

if $log ; then
	# convert frequency in seconds
	notify_frequency=$(($notify_frequency * 60))

	# set log message
	log_message="SSH connection success $user@$ip_source"

	# read last line of logs
	line=$(grep "$log_message" "$log_file" 2> /dev/null | tail -1)

	if [ -n "$line" ] ; then
		# get timestamp
		timestamp=$(get_timestamp "$line")

		# test if already notified
		if [ -n "$timestamp" ] ; then
			[ $(($now - $timestamp)) -le $notify_frequency ] && notify=false
		fi
	fi

	# write log
	write_log "$log_message"
fi

# no need to notify: exit
$notify || exit

if ! [ -f "$templates/$email_template".txt ] ; then
	write_log_error "Email template not found"
	exit 4
fi

# get hostname if not defined
[ -z "$hostname" ] && hostname=$lb_current_hostname

# prepare email subject
[ -n "$email_prefix" ] && email_subject="[$email_prefix] "
email_subject+="Notification of connection: $user@$hostname"

# prepare email command options
email_opts=(--subject "$email_subject")

# set sender
[ -n "$email_sender" ] && email_opts+=(--sender "$email_sender")

# html content
[ -f "$templates/$email_template".html ] && \
	email_opts+=(--html "$(replace_content "$templates/$email_template".html)")

# send email
lb_email "${email_opts[@]}" "$email_destination" \
	"$(replace_content "$templates/$email_template".txt)"

if [ $? != 0 ] ; then
	write_log_error "Email not sent"
	exit 3
fi
