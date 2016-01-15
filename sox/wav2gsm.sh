#!/bin/bash

if [ $# -eq 0 ]
then
  dir=`pwd`
else
  if [ -d "$1" ]
  then
    dir="$1"
  else
    echo "Error: invalid directory $1"
    exit
  fi
fi

for a in "$dir"/*.wav
do
  if [ -f "$a" ]
  then
  echo $a
  sox "$a" -r 8000 -c1 "`echo $a|sed -e s/wav//`gsm" resample -ql
  fi
done
