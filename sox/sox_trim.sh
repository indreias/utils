#!/bin/bash

t=$1
shift

odir=/tmp/$(basename $0)
mkdir -p $odir

echo "trim: $1 sec"
echo "odir: $odir"
echo

while [ $# -gt 0 ]
do
  echo $1
  if [ -f $1 ]
  then
    ifile=$1
    ofile=$odir/$(basename $1)
    i=$(sox $ifile $ofile stat 2>&1 | grep Length | awk -v t=$t '{i=$3-t;print i}')
    sox $ofile $ifile trim 0 $i
  fi
  shift
done
echo

rm -rf $odir
