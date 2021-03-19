#!/bin/bash
#
#  ssh-notify
#  A script to send notifications when somebody
#  made a connection in SSH.
#
#  MIT License
#  Copyright (c) 2017-2021 Jean Prunneaux
#  Website: https://github.com/pruje/ssh-notify
#
#  Version 1.4.2 (2021-03-19)
#

#
#  Initialization
#

# load libbash
source "$(dirname "$0")"/libbash/libbash.sh &> /dev/null
if [ $? != 0 ] ; then
	echo >&2 "ssh-notify: internal error"
	exit 1
fi

# if user is not in ssh-notify group, quit
if ! lb_ami_root ; then
	lb_in_group ssh-notify || exit 0
fi

# get context
ssh_info=$SSH_CONNECTION
details=$SSH_DETAILS
user=$lb_current_user


#
#  Default config
#

templates=$lb_current_script_directory/emails
email_template=default
log_date_format="%b %d %H:%M:%S"


#
#  Functions
#

# Read log file
# Usage: read_log FILTER
read_log() {
	grep "$*" "$log_file" 2> /dev/null | tail -1
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

	mkdir -p "$(dirname "$log_file")" && \
	echo "$(LC_ALL=C lb_timestamp2date -f "$log_date_format" $now) $hostname $user: ssh-notify: $*" >> "$log_file"
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
		s/{{hostname}}/$hostname/g;
		s/{{user}}/$user/g;
		s/{{details}}/$details/g;
		s/{{ip_source}}/$ip/g; s/{{date}}/$(lb_timestamp2date $now)/g" "$1"
}


#
#  Main program
#

# get options
while [ $# -gt 0 ] ; do
	case $1 in
		--ssh)
			[ -z "$2" ] && exit 1
			lb_ami_root && ssh_info=$2
			shift
			;;
		--user)
			[ -z "$2" ] && exit 1
			lb_ami_root && user=$2
			shift
			;;
		--details)
			[ -z "$2" ] && exit 1
			lb_ami_root && details=$2
			shift
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

# load config securely
if ! lb_import_config -t "$lb_current_script_directory"/ssh-notify.conf /etc/ssh/ssh-notify.conf ; then
	lb_error "ssh-notify: error in config"
	exit 1
fi

# get IP source (ignore aliases)
ip_source=$(echo $ssh_info | awk '{print $1}')

# check ip whitelist: do not continue
if [ -n "$ip_source" ] && [ ${#ip_whitelist[@]} -gt 0 ] ; then
	lb_array_contains $ip_source "${ip_whitelist[@]}" && exit
fi

# test config

# notify frequency: reset to default if not conform
if ! lb_is_integer $notify_frequency || [ $notify_frequency -lt 0 ] ; then
	notify_frequency=60
fi

if [ ${#email_destination} = 0 ] ; then
	lb_error "ssh-notify: error in config"
	exit 1
fi

# default log file path
[ -z "$log_file" ] && log_file=/var/log/ssh-notify.log

# sudo mode
if lb_istrue $sudo_mode ; then
	if lb_ami_root ; then
		# secure log file
		touch "$log_file" && \
		chown root:ssh-notify "$log_file" && chmod 600 "$log_file"
	else
		# check sudoers file
		if [ -f /etc/sudoers.d/ssh-notify ] ; then
			# re-run script
			sudo "$0" --ssh "$ssh_info" --user "$user" --details "$details"
			exit $?
		fi
	fi
fi

log=false

# if notify everytime (frequency=0), do not use logs
if [ "$notify_frequency" -gt 0 ] ; then
	# set log file for writing
	if lb_set_logfile -a "$log_file" ; then
		log=true
	else
		lb_error "ssh-notify: log file not writable"
	fi
fi

# get current timestamp
now=$(date +%s)

notify=true

if $log ; then
	# convert frequency in seconds
	notify_frequency=$(($notify_frequency * 60))

	# set log message
	log_message="SSH connection success $user@$ip_source"

	# test if log file is readable
	if [ -r "$log_file" ] ; then
		# read last line of logs
		line=$(read_log "$log_message")

		if [ -n "$line" ] ; then
			# get timestamp
			timestamp=$(get_timestamp "$line")
			if [ $? = 0 ] ; then
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
$notify || exit 0

if ! [ -f "$templates/$email_template".txt ] ; then
	write_log_error "Email template not found"
	exit 4
fi

# replace email destinations if current user defined
email_destination=$(echo "$email_destination" | sed "s/{user}/$user/g")

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
