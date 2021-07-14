#!/bin/bash
export PATH="$PATH:/usr/local/bin"

xo-cli --list-commands >/dev/null 2>&1 || { echo "CRITICAL - please provide credentials for desired XOA server";  exit 2 ; } ; 
all=0

#################
### variables ###

while getopts :ast: yo 
do
case $yo in
a)	all=1;;
s)	sum=1;;
t)	fetch_interval=$(($OPTARG*60*1000));;
?)	echo "alksdjlaksdj"
	exit 2
	;;
esac
done

today=`date +"%U_%d-%m-%y"`
week=`date +"%U"`
timestamp=$((`date +%s`*1000))
tmp_dir="/tmp/check_xoa_backup"
_su_day=0
_su_week=0
_pe_day=0
_pe_week=0
_in_day=0
_in_week=0
_sk_day=0
_sk_week=0
_fa_day=0
_fa_week=0

#################
### functions ###

gt_ts () {
[[ $(echo $line | awk -F "," '{print $1}') -gt $(($timestamp-$((60*60*24*1000)))) ]] 
}

feed_logs () {
case $line in 
	*success*)
		gt_ts && { su_day+=("$line"); _su_day=1 ;} || { su_week+=("$line") _su_week=2 ;}
		;;
	*pending*)
		gt_ts && { pe_day+=("$line"); _pe_day=4 ;} || { pe_week+=("$line"); _pe_week=8 ;}
		;;
	*interrupted*)
		gt_ts && { in_day+=("$line"); _in_day=16 ;} || { in_week+=("$line"); _in_week=32 ;}
		;;
	*skipped*)
		gt_ts && { sk_day+=("$line"); _sk_day=64 ;} || { sk_week+=("$line"i); _sk_week=128 ;}
		;;
	*failure*)
		gt_ts && { fa_day+=("$line"); _fa_day=256 ;} || { fa_week+=("$line"); _fa_week=512 ;}
		;;
esac
}
print_jobs () {
	echo -n "$(date -d @$(($(echo $job | awk -F "," '{print $1}')/1000)) +%d-%m-%y-%H:%M):""{$(echo "$job" | awk -F "," '{print $2 " " $3}')} "
}


[[ ! -z $(ls -1 "$tmp_dir"/$((week-1))_*.log 2>/dev/null) ]] && last_fetched=0 || last_fetched=`tail -1 "$tmp_dir"/last_fetched`

if [[ $last_fetched -eq 0 ]]
then
	rm -f "$tmp_dir"/$((week-1))_*.log
	fetch=10
elif [[ $(($timestamp-$last_fetched)) -gt $fetch_interval ]] 
	then
		fetch=1
	else
		fetch=0
fi

case $fetch in
	10)
		xo-cli backupNg.getAllLogs  > "$tmp_dir"/"$week"_00.log && echo $timestamp >> "$tmp_dir"/last_fetched
		;;
	1)
		xo-cli backupNg.getLogs after="$(($timestamp-$last_fetched))" >> "$tmp_dir"/"$today".log && echo $timestamp >> "$tmp_dir"/last_fetched
		;;
esac

if [[ $all -eq 1 ]]
then
for line in `jq -j '.[] | .id,",",.status,",",.jobName,"\n" ' "$tmp_dir"/"$week"_*.log | sort | uniq`
do
	feed_logs
done
else
for line in `jq -j '.[] | select (.id > "'$(($timestamp-$((60*60*24*7*1000))))'") | .id,",",.status,",",.jobName,"\n" ' "$tmp_dir"/"$week"_*.log | sort | uniq`
do
	feed_logs
done
fi

backup_sum=$(($_su_day+$_su_week+$_pe_day+$_pe_week+$_in_day+$_in_week+$_sk_day+$_sk_week+$_fa_day+$_fa_week))
backup_report=0; backup_report=$(($_fa_day+$_fa_week))

[[ $sum -eq 1 ]] && echo $backup_sum


if [[ $all -eq 1 ]]
then
for status in "su" "pe" "in" "sk" "fa"; do
    for time in "week" "day"; do
        for job in `eval echo '${'$status'_'$time'[@]}'`
			do 
				print_jobs
				echo
done
	done
		done
else
case $backup_report in
	256)
		echo -n "check backup"
		echo -n "today: "	
		for job in "${fa_day[@]}"
		do
			print_jobs
		done
		echo
		exit 2
		;;
	512)
		echo -n "check backup // "
		echo -n "this week: "
		for job in "${fa_week[@]}"
		do
			print_jobs
		done
		echo
		exit 1
		;;
	768)
		echo -n "check backup // "
		echo -n "today: "

		for job in "${fa_day[@]}"
		do
			print_jobs
		done
		echo -n "// this week: "
		for job in "${fa_week[@]}"
		do
			print_jobs
		done
		echo
		exit 2
		;;
	0)
		echo "nice"
		exit 0
		;;
esac
fi
