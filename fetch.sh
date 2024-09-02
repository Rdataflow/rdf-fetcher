#!/usr/bin/bash
export CHUNKSIZE=10000000
ENDPOINT=${2:-${ENDPOINT}}

function base { echo -n "${1//[^A-Za-z0-9 ]/_}" ; }
function tidy { echo -n ${1} | sed -e "s~^\s*\"*~~" | sed -e "s~\"*\s*$~~" ; }

while IFS="," read -r graph numtriples
do
    export graph=`tidy ${graph}`
    numtriples=`tidy ${numtriples}`
    mkdir -p out/$(base ${ENDPOINT})
    echo -n "fetching <${graph}> from endpoint ${ENDPOINT} (triples: ${numtriples}) "
    chunks=$(( (${numtriples}/${CHUNKSIZE}) ))
    chunk=0
    while [ ${chunk} -le ${chunks} ]
    do
	export offset=$(( ${chunk}*${CHUNKSIZE} ))
	echo -n .

	# fetch current chunk
	until $(lbzcat out/$(base ${ENDPOINT})/$(base ${graph}).${chunk}.ttl.bz2 2>/dev/null | tail -c2 | grep '.'>/dev/null)
	do cat prefix.rq graph.fetch.offset.rq \
            | envsubst \
            | sed 's~<>~?g~' \
            | curl ${ENDPOINT} -f -s --compressed -X POST -H 'Accept: text/turtle' -H 'Content-Type: application/sparql-query' --data-binary @- -o - \
            | lbzip2 > out/$(base ${ENDPOINT})/$(base ${graph}).${chunk}.ttl.bz2
        done

	# append chunk to single bz2
	cat out/$(base ${ENDPOINT})/$(base ${graph}).${chunk}.ttl.bz2 >> out/$(base ${ENDPOINT})/$(base ${graph}).ttl.bz2
	rm out/$(base ${ENDPOINT})/$(base ${graph}).${chunk}.ttl.bz2

	chunk=$(( ${chunk}+1 ))
    done
    echo
done < <( tail -n +2 ${1} )

cp ${1} out/$(base ${ENDPOINT})/index.csv
