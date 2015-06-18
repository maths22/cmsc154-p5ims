#!/usr/bin/env bash
set -o nounset

NAME=DB-03.sh
TEST=DB
JUNK=""
function junk {
  JUNK="$JUNK $@"
}
function cleanup {
  rm -rf $JUNK
}
trap cleanup err exit int term
trap "" hup
function dieifthere {
  if [[ -e $1 ]]; then
#    echo "P5IMS ERROR $TEST: $1 exists already; \"rm $1\" to proceed with testing" >&2
#    exit 1
    echo "P5IMS WARNING $TEST: $1 exists already; will now \"rm -f $1\"" >&2
    rm -f $1
 fi
}

CNDB=../cndb
if [[ ! -x $CNDB ]]; then
  echo "P5IMS ERROR $TEST: database canonical-izer $CNDB not found" >&2
  exit 1
fi
IMS=../ims
if [[ ! -x $IMS ]]; then
  echo "P5IMS ERROR $TEST: don't see $IMS executable" >&2
  exit 1
fi

DB1=db-test1.txt; dieifthere $DB1; junk $DB1 # the initial file
DB2=db-test2.txt; dieifthere $DB2; junk $DB2 # the copy made for ims
LOG=log.txt; dieifthere $LOG; junk $LOG

PORT=$[ 5000 + ($RANDOM % 3000)]
UA=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UB=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UC=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UD=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UE=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UF=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UG=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UH=UU_$(printf %06u $[ $RANDOM % 1000000 ])

touch $DB1
cat > $DB1 <<endofusers
8 users:
$UA
- $UB
- $UC
.
$UB
- $UA
- $UC
- $UD requested
.
$UC
- $UA
- $UB
- $UD toanswer
- $UE
- $UF
.
$UD
- $UB toanswer
- $UC requested
- $UE requested
- $UG toanswer
.
$UE
- $UC
- $UD toanswer
- $UG requested
.
$UF
- $UC
.
$UG
- $UE toanswer
- $UD requested
.
$UH
.
endofusers

echo "=== cp $DB1 $DB2"
cp $DB1 $DB2

echo "vvvvvvvvvvvvvvvvvvvvv cndb($DB2) before starting ims"
$CNDB $DB2
echo "^^^^^^^^^^^^^^^^^^^^^"

time0=$(ls -ln --time-style=+%T $DB2  | cut -d' ' -f 6)
echo "=== $DB2 time0 = $time0"

echo "=== sleep 4 before running server"
sleep 4

echo "=== (tail -f /dev/null) | $IMS -p $PORT -d $DB2 -i 10 &> $LOG &"
(tail -f /dev/null) | $IMS -p $PORT -d $DB2 -i 10 &> $LOG &

echo "=== sleep 1 to let server re-write database"
sleep 1

echo "=== killing server"
(killall -9 tail &> /dev/null) ||:
(killall -9 ims &> /dev/null) ||:

time1=$(ls -ln --time-style=+%T $DB2  | cut -d' ' -f 6)
echo "=== $DB2 time1 = $time1"

if [[ $time0 != $time1 ]]; then
  echo "P5IMS TEST $TEST: 1"
  okay=1
else
  echo "P5IMS TEST $TEST: 0 (db file $DB2 was not re-written at server start-up)"
  okay=0
fi

if [[ -v scoreFile ]]; then
  if [[ 1 -eq "$okay" ]]; then
    echo "$NAME 1/1" >> $scoreFile
  else
    echo "$NAME 0/1" >> $scoreFile
  fi
fi
