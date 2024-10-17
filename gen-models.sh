#!/bin/bash

cleanup () {
    # echo 'Running cleanup...'
    rm -rf "$tmpdir"
}

# branch-y in-place generation/parameter-expansion
generate (){
    for i in "${@:2}"
    do
        vid=${i%%=*}            # var name
        vrange=${i##*=}         # range
        vmin=${vrange%%\.\.*}   # left-bound
        vmax=${vrange##*\.\.}   # right-bound

        echo -e "mapping $vid with range $vmin-$vmax"

        expandparam $tmpdir $vid $vmin $vmax
    done
}

expandparam(){
    basefolder=$1
    vid=$2
    vmin=$3
    vmax=$4

    # catch err if no patterns matched 
    shopt -s failglob 
    
    echo -e "mapping $vid with range $vmin-$vmax"
    # iterate over files in the directory
    for f in "$basefolder"/*.xml; do
        echo -e "\tprocessing $f"
        
        for val in $(seq $vmin $vmax); do  
            echo -e "\t\tsubstituting $vid with $val"
            sed "s/const int ${vid}.*/const int ${vid} = ${val};/g" $f > "${f%*.xml}_${vid}${val}.xml"        
        done
        
        rm $f
    done
}

organizefiles (){
    # original model filename (redundant prefix)
    prefix=${1%%.*} 
    
    # catch err if no patterns matched 
    shopt -s failglob
    
    # delete previous/obsolete models (if any)
    rm -r ./case-studies
    # mkdir -p ./case-studies/{rev,nrev}/{fa,fp,vb}
    mkdir -p ./case-studies/{rev,nrev}/{fa,fp}

    # move/arrange generated models
    for f in $(ls ${tmpdir}); do
        mname=${f##${prefix}_}
        mkdir -p "./case-studies/${mname%.xml}/"
        cp $tmpdir/$f "./case-studies/${mname%.xml}/$mname"
    done

    mv ./case-studies/RV0*CTYPE1* ./case-studies/nrev/fp/
    mv ./case-studies/RV0*CTYPE2* ./case-studies/nrev/fa/
    mv ./case-studies/RV1*CTYPE1* ./case-studies/rev/fp/
    mv ./case-studies/RV1*CTYPE2* ./case-studies/rev/fa/
}

domainapprox(){
    verbosity=0
    echo -e "" > log.txt
    for f in ./case-studies/{nrev,rev}/{fp,fa}/*; do
        mname=${f##*/}
        mpath="$f/$mname.xml"
        nc=$(grep -Po '(?<=const int NC = )[0-9]*' $mpath)
        nv=$(grep -Po '(?<=const int NV = )[0-9]*' $mpath)
        initarr="$(seq 2 3 | sed 's/.*/0,/' | tr -d '\n')0"

        # abstraction 1
        ./app.js --input="$f/$mname.xml" --output="$f/$mname-a1.xml" --dmap="./output_files/t-asv/d3.txt" --t --v=$verbosity abstract targetVars="tally,freq" initVal="[$initarr],0" targetTemplate=Authority >> log.txt 2>&1

        # abstraction 2
        ./app.js --input="$f/$mname-a1.xml" --output="$f/$mname-a2.xml" --dmap="$f/d-a2.txt" --t --v=$verbosity approx 1 targetVars="mode" initVal="0" targetTemplate=Voter >> log.txt 2>&1

        ./app.js --input="$f/$mname-a1.xml" --output="$f/$mname-a2.xml" --dmap="$f/d-a2.txt" --t --v=$verbosity abstract targetVars="mode" initVal="0" targetTemplate=Voter >> log.txt 2>&1

        # abstraction 3
        ./app.js --input="$f/$mname-a2.xml" --output="$f/$mname-a3.xml" --dmap="$f/d-a3.txt" --t --v=$verbosity approx 1 targetVars="voted,mode,p,np" initVal="0,0,0,0" targetTemplate="Voter_" >> log.txt 2>&1

        ./app.js --input="$f/$mname-a2.xml" --output="$f/$mname-a3.xml" --dmap="$f/d-a3.txt" --t --v=$verbosity abstract targetVars="voted,mode,p,np" initVal="0,0,0,0" targetTemplate="Voter_" >> log.txt 2>&1
        
        if  ((nv > 1)); then
            sed -i "s:1,NV] id:1,1] id:g" $f/$mname-a3.xml
            sed -i "s/system Voter/system Voter, Voter_/g" $f/$mname-a3.xml
            # echo -e "changed $mname"
        else 
            echo -e "a3 has no change for $mname"
        fi
        # echo -e $f
        # echo -e 
    done
}


if [[ $# -eq 0 ]] ; then
    echo 'No args provided!!!'
    exit 0
fi

tmpdir=$(mktemp -d) # creates unique dir in /tmp/...
# echo -e "Created temporary directory $tmpdir"

trap cleanup EXIT   # run cleanup on signal EXIT

# generate models in bulk
(cp $1 "${tmpdir}/" && cd $tmpdir && generate "$@")

# arrange concrete models
(organizefiles ${1##*/}) 

# approximate the local domains
domainapprox
