#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=DB-01.sh
GRADEFILE=CummulativeTestReport.txt
TEST=DB
IMSPID=0
JUNK=""
function junk {
  JUNK="$JUNK $@"
}
function cleanup {
  rm -rf $JUNK
  if [[ $IMSPID > 0 ]]; then
    kill -9 $IMSPID &> /dev/null
  fi
}
trap cleanup err exit int term
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
TXTIMC=../txtimc
if [[ ! -x $IMS ]]; then
  echo "P5IMS ERROR $TEST: don't see $IMS executable" >&2
  exit 1
fi
if [[ ! -x $TXTIMC ]]; then
  echo "P5IMS ERROR $TEST: don't see $TXTIMC executable" >&2
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
PAUSE=4

touch $DB1
cat > $DB1 <<endofusers
0 users:
endofusers

echo "=== cp $DB1 $DB2"
cp $DB1 $DB2

echo "vvvvvvvvvvvvvvvvvvvvv cndb($DB2) before starting ims"
$CNDB $DB2
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "=== (tail -f /dev/null) | $IMS -p $PORT -d $DB2 -i $PAUSE &> $LOG &"
(tail -f /dev/null) | $IMS -p $PORT -d $DB2 -i $PAUSE &> $LOG &
IMSPID=$!

echo "=== sleep 1"
sleep 1

echo "=== rm -f $DB2"
rm -f $DB2

echo "=== sleep $[$PAUSE+2] (waiting for $DB2 to be re-written)"
sleep $[$PAUSE+2]

okay=0
if [[ -e $DB2 ]]; then
  echo "vvvvvvvvvvvvvvvvvvvvv cndb($DB2), after running $IMS"
  $CNDB $DB2
  echo "^^^^^^^^^^^^^^^^^^^^^"
  echo "vvvvvvvvvvvvvvvvvvvvv difference between canonical(input) and canonical(output)"
  $CNDB $DB1 $DB2 | sed 's/^.*\///'
  echo "^^^^^^^^^^^^^^^^^^^^^"
  ! $CNDB $DB1 $DB2 > /dev/null
  okay=$?
  echo -n "P5IMS TEST $TEST: $okay"
  if [[ 0 -eq "$okay" ]]; then
    echo " (there was a difference in the database)"
  else
    echo ""
  fi
else
  echo "P5IMS TEST $TEST: 0 (db file $DB2 was not re-written in $PAUSE seconds)"
  echo "log file follows:"
  cat $LOG
fi

if [[ 1 -eq "$okay" ]]; then
    echo "$NAME" >> $GRADEFILE
fi
