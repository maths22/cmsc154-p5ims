#!/usr/bin/env bash
set -o nounset

NAME=FRIEND_STATUS-02.sh
TEST=FRIEND_STATUS
JUNK=""
function junk {
  JUNK="$JUNK $@"
}
function cleanup {
  rm -rf $JUNK
  # make really sure nothing is left running;
  # apologies if this kills more than intended
  (killall -9 tail &> /dev/null) ||:
  (killall -9 ims &> /dev/null) ||:
  (killall -9 txtimc &> /dev/null) ||:
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

touch $CIN
echo "login alice" >> $CIN
echo "friend_list" >> $CIN
echo "sleep 6"  >> $CIN

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN
echo "^^^^^^^^^^^^^^^^^^^^^"

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
sleep 1

$TXTIMC -s localhost -p $PORT < $CIN &> $COUT

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT
echo "^^^^^^^^^^^^^^^^^^^^^"

statMsgs1=$(grep "STATUS david FRIEND_TOANSWER ACTIVE_NOT" $COUT | wc -l)
statMsgs2=$(grep "STATUS bob FRIEND_YES ACTIVE_NOT" $COUT | wc -l)

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

score=0
if [[ $statMsgs1 == 2 ]]; then (( score++ )); fi
if [[ $statMsgs2 == 2 ]]; then (( score++ )); fi

if [[ -v scoreFile ]]; then
  echo "$NAME $score/2" >> $scoreFile
fi
