#!/bin/bash

while getopts c:w:t:dlh aaa 
do
case $aaa in
c)	CRIT=$OPTARG;;
w)	WARN=$OPTARG;;
t)	TYPE=$OPTARG;;
d)	DEBUG=1;;
l)	LIST=1;;
h)	HELP=1;;
?)	echo "chill"
	exit 2
	;;
esac
done

IFS=$'\n'
STATE=0
_CRIT=0
_WARN=0

help () {
        echo "Usage:"
        echo -e "\t -c critical threshold"
        echo -e "\t"
        echo -e "\t -w warning threshold"
        echo -e "\t"
        echo -e "\t -t sr type"
        echo -e "\t"
        echo -e "\t -l: list available types"
        echo -e "\t"
        echo -e "\t -d: print array values"
        echo -e "\t"
        echo -e "\t $0 -p 80 -w 60 -t ext"
        echo -e "\t"
}

[[ $HELP -eq 1 ]] && help && exit 1

pr_type () {
for type in `xe sr-list params=type | sort | uniq | awk '{print $NF}'`
do
	types+=("$type")
done
for i in ${types[@]}
do
	echo $i
done
}

[[ $LIST -eq 1 ]] && pr_type && exit 1


for host in `xe host-list params=name-label | awk '{print $NF}'`
do
	hosts+=("$host")
done


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
