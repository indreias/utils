#!/bin/bash

# $1 = location for bare git repositories

cd $1
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
