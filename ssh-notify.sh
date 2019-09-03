#!/bin/bash
#
#  ssh-notify
#  A script to send notifications when somebody
#  made a connection in SSH.
#
#  MIT License
#  Copyright (c) 2017-2019 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#
#  Version 1.1.1 (2019-06-29)
#

#
#  Initialization
#

declare -r version=1.1.1

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "ssh-notify: internal error"
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
	echo "ssh-notify version $version"
	echo
	echo "Usage: $0 [OPTIONS]"
	echo
	echo "Options:"
	echo "  -c, --config PATH  Specify a config file (default /etc/ssh/ssh-notify.conf)"
	echo "  -h, --help         Print this help"
}


# Read log file
# Usage: read_log FILTER
read_log() {
	if lb_istrue $journalctl ; then
		# limit print for journalctl
		local date_limit=$(lb_timestamp2date -f "%Y-%m-%d %H:%M:%S" $(($now - $notify_frequency)))

		journalctl --output short-full --since "$date_limit" 2> /dev/null | grep "$*" | tail -1
	else
		grep "$*" "$log_file" 2> /dev/null | tail -1
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
	d=$(echo "$*" | awk "{for(i=1;i<=$spaces;++i) printf \$i \" \"}")

	# get real date
	date=$(date -d "$d" '+%Y-%m-%d %H:%M:%S %Z' 2> /dev/null) || return 1

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
		echo "$(LC_ALL=C lb_timestamp2date -f "$log_date_format" $now) $hostname $user: ssh-notify: $*" >> "$log_file"
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
	local ip=$ip_source
	[ -z "$ip" ] && ip=UNKNOWN

	sed "s/{{email_from}}/$email_sender/g;
		s/{{email_to}}/$email_monitoring/g;
		s/{{user}}/$user/g; s/{{hostname}}/$hostname/g;
		s/{{ip_source}}/$ip/g; s/{{date}}/$(lb_timestamp2date $now)/g" "$1"
}


#
#  Main program
#

# get context
ssh_info=$SSH_CONNECTION
user=$lb_current_user

# get options
while [ $# -gt 0 ] ; do
	case $1 in
		-c|--config)
			[ -z "$2" ] && exit 1
			config_file=$2
			shift
			;;
		--ssh)
			[ -z "$2" ] && exit 1
			[ "$lb_current_user" == root ] && ssh_info=$2
			shift
			;;
		--user)
			[ -z "$2" ] && exit 1
			[ "$lb_current_user" == root ] && user=$2
			shift
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

# no ssh: cancel
if [ -z "$ssh_info" ] ; then
	lb_error "Hey dude, you are not a ssh user!"
	exit 1
fi

# get IP source (ignore aliases)
ip_source=$(echo $ssh_info | awk '{print $1}')

# get current timestamp
now=$(date +%s)

# analyse config template
lb_read_config -a "$lb_current_script_directory"/ssh-notify.conf

# load config and import only good variables
if ! lb_import_config "$config_file" "${lb_read_config[@]}" ; then
	lb_error "ssh-notify: error in config"
	exit 1
fi

# sudo mode: rerun script
if lb_istrue $sudo_mode && [ "$lb_current_user" != root ] ; then
	# test if user is part of ssh-notify group
	if groups 2> /dev/null | grep -wq ssh-notify ; then
		sudo "$0" -c "$config_file" --ssh "$ssh_info" --user $user
		exit $?
	fi
fi

# test config

# notify frequency: reset to default if not conform
lb_is_integer $notify_frequency || notify_frequency=60

# check user whitelist: do not continue
if [ ${#user_whitelist[@]} -gt 0 ] ; then
	lb_array_contains $user "${user_whitelist[@]}" && exit
fi

# check ip whitelist: do not continue
if [ -n "$ip_source" ] && [ ${#ip_whitelist[@]} -gt 0 ] ; then
	lb_array_contains $ip_source "${ip_whitelist[@]}" && exit
fi

if [ -z "$email_destination" ] ; then
	lb_error "ssh-notify: error in config"
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
	if ! lb_istrue $logger && ! lb_set_logfile -a "$log_file" ; then
		lb_error "ssh-notify: log file not writable"
		log=false
	fi
fi

if $log ; then
	# convert frequency in seconds
	notify_frequency=$(($notify_frequency * 60))

	# set log message
	log_message="SSH connection success $user@$ip_source"

	# test if log file is readable
	log_readable=true
	if ! lb_istrue $journalctl && ! [ -r "$log_file" ] ; then
		lb_error "ssh-notify: log file not readable"
		log_readable=false
	fi

	if $log_readable ; then
		# read last line of logs
		line=$(read_log "$log_message")

		if [ -n "$line" ] ; then
			# get timestamp
			timestamp=$(get_timestamp "$line")
			if [ $? == 0 ] ; then
				# test if already notified
				if lb_is_integer $timestamp ; then
					[ $(($now - $timestamp)) -le $notify_frequency ] && notify=false
				fi
			else
				lb_error "ssh-notify: cannot get timestamp. Please check log date format."
			fi
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
