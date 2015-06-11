#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=FRIEND_LIST-01.sh
GRADEFILE=CummulativeTestReport.txt
TEST=FRIEND_LIST
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

PORT=$[ 5000 + ($RANDOM % 3000)]
UU=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UU_OTHER=UU_$(printf %06u $[ $RANDOM % 1000000 ])
PAUSE=3

DB=db-test.txt; dieifthere $DB; junk $DB
CIN=in.txt; dieifthere $CIN; junk $CIN
COUT=out.txt; dieifthere $COUT; junk $COUT
LOG=log.txt; dieifthere $LOG; junk $LOG

cat > $DB <<endofusers
3 users:
alice
- david toanswer
- bob
.
bob
- alice
- david
.
david
- alice requested
- bob
.
endofusers

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

touch $CIN
echo "login bob" >> $CIN
echo "friend_list" >> $CIN
echo "sleep 6"  >> $CIN

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT < $CIN &> $COUT

echo "=== sleep $[$PAUSE+2] (waiting for $DB to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv final $DB"
cat $DB
echo "^^^^^^^^^^^^^^^^^^^^^"

statMsgs1=$(grep "*** friend alice: ACTIVE_NOT ***" $COUT | wc -l)
statMsgs2=$(grep "*** friend david: ACTIVE_NOT ***" $COUT | wc -l)

if [[ $statMsgs1 == 2 ]]; then
    echo "P5IMS TEST $TEST: STAT MSGS1 1"
else
    echo "P5IMS TEST $TEST: STAT MSGS2 0"
fi

if [[ $statMsgs2 == 2 ]]; then
    echo "P5IMS TEST $TEST: STAT MSGS1 1"
else
    echo "P5IMS TEST $TEST: STAT MSGS2 0"
fi

if [[ $statMsgs1 == 2 && $statMsgs2 == 2 ]]; then
    echo "$NAME" >> $GRADEFILE
fi
