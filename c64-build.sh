#!/bin/bash -e

export PATH=$PATH:~/c64/cc65/bin/

program="GalaForce1-c64"

source=$1
if [ -z "$source" ] ; then
  source="Master-c64.mak.asm"
fi


cl65 -m map.txt -t c64 -C galaforce1-c64.cfg -o ${program}.PRG -l ${program}.list ${source} --verbose
