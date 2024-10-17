#!/bin/bash

VERIF_EXEC='./uppaal64-4.1.24/bin-Linux/verifyta'
VMAX=32000000  # KB 

if [[ ! -f $VERIF_EXEC ]] ; then
    echo -e "ERR: cannot find verifyta.exe at $VERIF_EXEC"
    exit 1
fi

QFP="forced-participation.q"
echo -e 'A[] Voter(1).np imply Voter(1).voted!=DISOBEY' > $QFP

QFA="forced-abstention.q"
echo -e 'A[] Voter(1).np imply Voter(1).voted==OBEY' > $QFA


runverif(){
    if [[ -f $1 ]] ; then
        TNONCE=$(date +'%Y-%m-%d-%H-%M-%S')
        LOGFILE="${1%/*}/$TNONCE.log"        
        RESFILE="${1%/*}/result.csv"

        res=$(ulimit -v $VMAX; $VERIF_EXEC -u $1 $2 2>&1) 
        str=""

        # save the output in (temporary) logfile
        echo -e $res > $LOGFILE

        # extract metadata
        sts=$(echo $res | grep -Po '(?<=States stored : )(\d+)(?= states)')
        ste=$(echo $res | grep -Po '(?<=States explored : )(\d+)(?= states)')
        cpu=$(echo $res | grep -Po '(?<=CPU user time used : )(\d+)(?= ms)')
        vmem=$(echo $res | grep -Po '(?<=Virtual memory used : )(\d+)(?= KiB)')
        rmem=$(echo $res | grep -Po '(?<=Resident memory used : )(\d+)(?= KiB)')
        
        sat=$(echo $res | grep -Po 'Formula is satisfied')    
        
        if [[ -z $sat ]]; then
            nsat=$(echo $res | grep -Po 'Formula is NOT satisfied')
            if [[ ! -z $nsat ]]; then
                str=$(echo -e "not sat")
            else
                str=$(echo -e "memout")
            fi
        else
            str=$(echo -e "${sts}${DELIM}${ste}${DELIM}${cpu}${DELIM}${rmem}${DELIM}${vmem}")
        fi

        GLOBAL_RES+="${ENTRY_PREFIX}${1##*/}${DELIM}${str}${ENTRY_SUFFIX}\n"
        echo -e "${1##*/}${DELIM}${str}" >> $RESFILE
    else
        echo 'Missing input model'
        exit 1
    fi
}

GLOBAL_RES=''
ENTRY_PREFIX=''
ENTRY_SUFFIX=''
DELIM=','

for f in ./case-studies/**; do
    for ff in $f/**; do
        ENTRY_SUFFIX="${DELIM}${ff##*/}"
        for fff in $ff/**; do
            echo -e "" > "${fff}/result.csv"
            nc=$(echo -e "$fff" | grep -Po '(?<=NC)[0-9]*' )
            nv=$(echo -e "$fff" | grep -Po '(?<=NV)[0-9]*' )
            ENTRY_PREFIX="${f##*/}${DELIM}${nv}${DELIM}${nc}${DELIM}"
            for ffff in $fff/*.xml; do
                if [[ ${ff##*/} = 'fa' ]]; then 
                    runverif $ffff $QFA
                fi
                if [[ ${ff##*/} = 'fp' ]]; then 
                    runverif $ffff $QFP
                fi
            done
        done
    done
done

echo -e "$GLOBAL_RES" > ./all-results.csv
rm $QFP
rm $QFA
