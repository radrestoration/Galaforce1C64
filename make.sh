#!/bin/bash -e

if [ -z "${BEEBASM}" ] ; then
  BEEBASM=beebasm
fi

${BEEBASM} -i Prebuild.mak

${BEEBASM} -i Master.mak -di G1_BLANK.SSD -do Galaforce1BBC.ssd

ls -l *.ssd
