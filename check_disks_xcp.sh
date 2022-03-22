#!/usr/bin/env bash

while getopts c:w:t:dlh cwtdlh
do
    case "${cwtdlh}" in
        c) CRIT=$OPTARG;;
        w) WARN=$OPTARG;;
        t) TYPE=$OPTARG;;
        d) DEBUG=1;;
        l) LIST=1;;
        h) HELP=1;;
        ?) printf "%s \n" "stop using invalid options, man."
           exit 2
           ;;
    esac
done

help () {
echo -en "Usage:
\t $0 -c
\t cirical threshold \n
\t $0 -w
\t warning threshold \n
\t $0 -t
\t storage repository type (eg. ext or lvm) \n
\t $0 -l 
\t list available SR types \n
\t $0 -d
\t print values contained in arrays
Example: $0 -c 80 -w 60 -t ext \n"
    exit 0
}

IFS=$'\n'
STATE=0
_CRIT=0
_WARN=0
is_shared=$(xe sr-list shared=true type="${TYPE}")
# shellcheck disable=SC2207
hosts+=($(xe host-list params=name-label | awk '!/^\s*$/ {print $NF}'))
# shellcheck disable=SC2207
types+=($(xe sr-list params=type | awk '{print $NF}' | sort | uniq))
sr_params='uuid,host,physical-size,physical-utilisation,name-label'

round () {
    awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}'
}

trim () {
    awk -F "RO)|RW):" '{print $3 "on" $4}' \
        | sed 's#physical-utilisation\ (\|\ host\ (##g; s#on:#on#g' 
}

[[ "${HELP}" -eq 1 ]] && help

if [[ "${LIST}" -eq 1 ]] 
then
    for ((i=0;i<${#types[@]};i++))
    do
        echo "${types[i]}"
    done
    exit 0
fi   

# shellcheck disable=SC2207
if [[ "${is_shared}" ]]
then
    srs+=($(xe sr-list params="${sr_params}" shared=true type="${TYPE}" \
        | paste -s -d " "))
else
    for ((j=0;j<${#hosts[@]};j++))
    do
        srs+=($(xe sr-list params="${sr_params}" type="${TYPE}" host="${hosts[j]}" \
            | paste -s -d " "))
    done
fi

for ((k=0;k<${#srs[@]};k++))
do
    used=$(printf "%s \n" "${srs[k]}" | awk '{print $18}')
    total=$(printf "%s \n" "${srs[k]}" | awk '{print $22}')
    percent=$(printf "%s \n" "scale=3; ${used}/${total}*100" | bc \
        | round )
    text=$(printf "%s \n" "${srs[k]}" | xargs | trim )
    # shellcheck disable=SC2207
    if [[ "${percent}" -ge CRIT ]]
    then
        crit+=($(printf "%s \n" "${text} usage at ${percent}%"))
        _CRIT=2
    elif [[ "${percent}" -ge WARN ]]
    then
        warn+=($(printf "%s \n" "${text} usage at ${percent}%"))
        _WARN=1
    else
        okay+=($(printf "%s \n" "${text} usage at ${percent}%"))
    fi
done

STATE=$((_CRIT+_WARN))

debug () {
for sr in "${srs[@]}"
do
printf "%s \n" "${sr}"
done
}

print () {
    N=$(eval printf "%s" '${#'"${1}"'[@]}')
    for ((a=0;a<N;a++))
    do
        bruh=$(printf "%s" "$(eval printf "%s" '${'"${1}"'[a]}')")
        printf " {%s} " "$(printf "%s" "${bruh}" | xargs)"
    done
}

[[ $DEBUG -eq 1 ]] && debug

case "${STATE}" in
    1)
        printf "%s" "WARN: "
        print warn
        echo
        exit 1
        ;;
    2)
        printf "%s" "CRIT: "
        print crit
        echo
        exit 2
        ;;
    3)
        printf "%s" "CRIT: "
        print crit
        printf "%s" "WARN: "
        print warn
        echo
        exit 2
        ;;
    0)
        printf "%s" "nice"
        print okay
        echo
        exit 0
        ;;
esac
