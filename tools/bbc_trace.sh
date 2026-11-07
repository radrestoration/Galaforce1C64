#!/bin/bash -e
# Build the original BBC Galaforce 1 (from ../Galaforce1BBC, which is not modified) into build/bbc and
# record the aliens' positions for every wave by running the real game headless (tools/g1_overlap.py).
#   tools/bbc_trace.sh [max_iterations_per_wave]   -> build/bbc/out.ssd, build/bbc/syms.txt, build/trace/wN.json
cd "$(dirname "$0")/.."
[ -f tools.cfg ] && . tools.cfg
BEEBASM=${BEEBASM:-beebasm}; BEEBASM=${BEEBASM/#\~/$HOME}
SRC=../Galaforce1BBC
B=build/bbc
mkdir -p $B build/trace
cp -r $SRC/src $SRC/object $SRC/O.DOWN $SRC/G1_BLANK.SSD $SRC/bas_extra $B/
# beebasm on Linux wants / in paths, and the BASIC loader is not needed
sed -E '/INCLUDE|INCBIN/ s#\\#/#g; /PUTBASIC/d' $SRC/Master.mak > $B/Master.mak
printf '\n' >> $B/Master.mak
for s in exec main_loop alst algra alx aly curwave wait_for_space collision lives myx myy; do
  printf 'PRINT "SYM %s ",~%s\n' $s $s >> $B/Master.mak
done
(cd $B && $BEEBASM -i Master.mak -di G1_BLANK.SSD -do out.ssd | grep '^SYM' > syms.txt)
N=${1:-5000}
for w in $(seq 0 15); do
  python3 -I tools/g1_overlap.py $B/out.ssd $B/syms.txt $w $N build/trace/w$w.json &
done
wait
