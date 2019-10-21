#!/bin/bash

while [ "$1" != "" ]; do
	date=`date "+%Y-%m-%d"`

	echo "Building $1"

	command="docker build --no-cache --file  ${1}.dockerfile -t ${1}-${date} ."
	$command

	shift
done

