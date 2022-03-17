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

[[ $HELP -eq 1 ]] && help

# shellcheck disable=SC2207
types+=($(xe sr-list params=type | awk '{print $NF}' | sort | uniq))

if [[ ${LIST} -eq 1 ]] 
then
    for ((i=0;i<${#types[@]};i++))
    do
        echo "${types[i]}"
    done
fi   

# shellcheck disable=SC2207
hosts+=($(xe host-list params=name-label | awk '{print $NF}'))

shared () {
for sr in `xe sr-list params=uuid,host,physical-size,physical-utilisation,name-label shared=true type=$TYPE | paste -s -d " "`
do
    srs+=("$sr")
done
}

local () {
for host in ${hosts[@]}
do
    for sr in `xe sr-list params=uuid,host,physical-size,physical-utilisation,name-label  host=$host type=$TYPE | paste -s -d " "`
    do
        srs+=("$sr")
    done
done
}

pr_sr () {
    echo -n "{`echo $sr | awk -F ":" '{print $3}' | awk '{print $1 " " $2}'` on `echo $sr | awk -F ":" '{print $4}' | awk '{print $1}'` usage at `echo $sr | awk -F ":" '{print $6}' |
     awk '{print $2}' | awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}i'`%} "
}

[[ ! -z `xe sr-list shared=true type=$TYPE` ]] && shared || local

for sr in ${srs[@]}
do
    percent+=("$(echo "scale=3; $(echo $sr | awk '{print $18}')/$(echo $sr | awk '{print $22}')*100" | bc)")
done

for ((i=0;i<${#srs[@]};i++))
do    
    if [[ ` echo ${percent[i]}|awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}'` -gt CRIT ]]
    then 
        crit+=(`echo ${srs[i]} ${percent[i]} crit`) && _CRIT=2
    elif [[ ` echo ${percent[i]}|awk '{print ($0-int($0)<0.499)?int($0):int($0)+1}'` -gt WARN ]]
    then
        warn+=(`echo ${srs[i]} ${percent[i]} warn`) && _WARN=1
    fi
done

STATE=$((_CRIT+_WARN))

debug () {
for sr in ${srs[@]}
do
echo $sr 
done
}

[[ $DEBUG -eq 1 ]] && debug


case $STATE in
    1)
        echo -n "WARN: "
    for sr in ${warn[@]}
    do
        pr_sr
    done
    echo
    exit 1
    ;;
    2)
        echo -n "CRIT: "
    for sr in ${crit[@]}
    do
        pr_sr
    done
    echo
    exit 2
    ;;
    3)
        echo -n "CRIT: "
    for sr in ${crit[@]}
    do
        pr_sr
    done
        echo -n "WARN: "
    for sr in ${warn[@]}
    do
        pr_sr
    done
    echo
    exit 2
    ;;
    0)
    echo "nice"
    exit 0
    ;;
esac
