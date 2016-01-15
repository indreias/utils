#!/bin/bash

#
# Author:  Ioan Indreias
# License: MIT, Copyright (c) 2016 Ioan Indreias
#
# version: 1 - initial release
#

# $1 = location for bare git repositories

if [ -z "$1" ]
then
  echo "Please provide the location for bare git repositories"
  exit 1
else
  if [ -d "$1" ]
  then
    cd $1
  else
    echo "Error: could not change directory to '$1'"
    exit 2
  fi
fi

echo "Location: $1"
find . -maxdepth 1 -type d | while read d
do
  info=$(git --git-dir="$d" branch 2>&1)
  if [ $? -eq 0 ]
  then
    echo "Repository: $(basename $d)"
    echo -e "$info" | grep -v "^  ;$" | awk '{print $NF}' | while read b
    do
      echo -e "\tBranch: $b"
      git --git-dir="$d" ls-tree --full-tree -r $b
      echo
    done
    echo
  fi
done
