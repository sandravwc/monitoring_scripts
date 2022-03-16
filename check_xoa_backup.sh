#!/usr/bin/env bash

export PATH="$PATH:/usr/local/bin"

xo-cli --list-commands >/dev/null 2>&1 || { 
    printf "%s \n" "CRITICAL - please provide credentials for desired XOA server"
    printf "%s \n" "example: xo-cli --register --expiresIn 311040000000 http://xoa.local:80 user pass"
    exit 2
    }
all=0

#################
### pre--exec ###

while getopts :ast:h asth 
do
    case "${asth}" in
        a)  all=1;;
        s)  sum=1;;
        t)  fetch_interval=$((OPTARG*60*1000));;
        h)  HELP=1;;
        ?)  echo "stop using invalid options, man."
            exit 2
            ;;
    esac
done

help () {
echo -en "Usage:
\t $0 -a 
\t print all jobs \n
\t $0 -s
\t print current status depicted as a sum \n
\t \t 1   - at least 1 job success today
\t \t 2   - at least 1 job success this week
\t \t 4   - at least 1 job pending today
\t \t 8   - at least 1 job pending this week
\t \t 16  - at least 1 job interrupted today
\t \t 32  - at least 1 job interrupted this week
\t \t 64  - at least 1 job skipped today
\t \t 128 - at least 1 job skipped this week
\t \t 256 - at least 1 job failed today
\t \t 512 - at least 1 job failed this week \n
\t $0 -t
\t log fetch interval in minutes \n
\t $0 -h
\t show this dialog \n 
Example: $0 -t 60 -a \n"
    exit 0
}

[[ "${HELP}" == 1 ]] && help

today=$(date +"%U_%d-%m-%y")
week=$(date +"%U")
timestamp=$(($(date +%s)*1000))
weeko=$((timestamp-$((60*60*24*1000))))
tmp_dir="/tmp/check_xoa_backup"
backup_report=0 
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

print_jobs () {
    echo -n "$(date -d @$(($(echo "${job}" \
        | awk -F "," '{print $1}')/1000)) +%d-%m-%y-%H:%M):""{$(echo "${job}" \
            | awk -F "," '{print $2 " " $3}')} "
}

sort_logs () {
    line_ts=$(echo "${line}" \
        | awk -F "," '{print $1}')
    if [[ "${line_ts}" -gt "${weeko}" ]]
    then
        case "${line}" in 
            *success*)      su_day+=("${line}") && _su_day=1   ;; 
            *pending*)      pe_day+=("${line}") && _pe_day=4   ;;
            *interrupted*)  in_day+=("${line}") && _in_day=16  ;;
            *skipped*)      sk_day+=("${line}") && _sk_day=64  ;;
            *failure*)      fa_day+=("${line}") && _fa_day=256 ;;
        esac
    else
        case "${line}" in 
            *success*)      su_week+=("${line}") && _su_week=2   ;; 
            *pending*)      pe_week+=("${line}") && _pe_week=8   ;;
            *interrupted*)  in_week+=("${line}") && _in_week=32  ;;
            *skipped*)      sk_week+=("${line}") && _sk_week=128 ;;
            *failure*)      fa_week+=("${line}") && _fa_week=512 ;;            
        esac        
    fi
}

print_stats () {
    for job in $(eval echo '${'"${1}"'_'"${2}"'[@]}')
    do
        print_jobs
    done
}

#################
### action!!! ###

# check if data needs to be fetched
if [[ -f "$tmp_dir/$((week-1))_*.log" ]] 
then
    rm -f "${tmp_dir}/$((week-1))_*.log"
    xo-cli backupNg.getAllLogs \
        > "${tmp_dir}"/"${week}"_00.log
    echo "${timestamp}" >> "${tmp_dir}/last_fetched"
else
    last_fetched=$(tail -1 "${tmp_dir}/last_fetched")
    t_minus_fetch=$((timestamp-last_fetched))
    if [[ "${t_minus_fetch}" -gt "${fetch_interval}" ]]
    then
        xo-cli backupNg.getLogs after="$((timestamp-last_fetched))" \
            >> "${tmp_dir}"/"${today}".log 
        echo "${timestamp}" >> "${tmp_dir}/last_fetched"
    fi
fi

if [[ "${all}" -eq 1 ]]
then
    for line in $(jq -j '.[] | .id,",",.status,",",.jobName,"\n" ' "${tmp_dir}"/"${week}"_*.log \
        | sort | uniq )
    do
        sort_logs
    done
else
    for line in $(jq -j '.[] | select (.id > "'${weeko}'") | .id,",",.status,",",.jobName,"\n" ' "${tmp_dir}"/"${week}"_*.log \
        | sort | uniq )
    do
        sort_logs
    done
fi

backup_sum=$((_su_day+_su_week+_pe_day+_pe_week+_in_day+_in_week+_sk_day+_sk_week+_fa_day+_fa_week))
backup_report=$((_fa_day+_fa_week))

[[ "${sum}" -eq 1 ]] && echo "${backup_sum}"

# do evals so i dont need to write that much
if [[ "${all}" -eq 1 ]]
then
    for status in "su" "pe" "in" "sk" "fa"
    do
        for time in "week" "day"
        do
            for job in $(eval echo '${'"${status}"'_'"${time}"'[@]}')
            do
                print_jobs
                echo
    done
        done
            done
fi

# switch is more readable...
case "${backup_report}" in
    256)
        echo -n "check backup"
        echo -n "today: "
        print_stats fa day
        echo
        exit 2
        ;;
    512)
        echo -n "check backup // "
        echo -n "this week: "
        print_stats fa week
        echo
        exit 1
        ;;
    768)
        echo -n "check backup // "
        echo -n "today: "
        print_stats fa day
        echo -n "// this week: "
        print_stats fa week
        echo
        exit 2
        ;;
    0)
        echo "nice"
        exit 0
        ;;
esac
