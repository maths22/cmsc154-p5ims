#!/usr/bin/env bash
set -o nounset

NAME=LOGOUT-01.sh
TEST=LOGOUT
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
2 users:
alice
.
bob
.
endofusers

touch $CIN
echo "register $UU" >> $CIN
echo "login $UU" >> $CIN
echo "logout" >> $CIN
echo "sleep 3"  >> $CIN

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN
echo "^^^^^^^^^^^^^^^^^^^^^"

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
sleep 1

$TXTIMC -s localhost -p $PORT < $CIN &> $COUT

echo "=== sleep $[$PAUSE+2] (waiting for $DB to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv final $DB"
cat $DB
echo "^^^^^^^^^^^^^^^^^^^^^"

gotackcnct=$(grep "ACK CONNECT" $COUT | wc -l)
gotackreg=$(grep "ACK REGISTER $UU" $COUT | wc -l)
gotacklogin=$(grep "ACK LOGIN $UU" $COUT | wc -l)
gotacklogout=$(grep "ACK LOGOUT" $COUT | wc -l)
indb=$(grep $UU $DB | wc -l)

echo "P5IMS TEST $TEST: ACK CONNECT $gotackcnct"
echo "P5IMS TEST $TEST: ACK REGISTER $gotackreg"
echo "P5IMS TEST $TEST: ACK LOGIN $gotacklogin"
echo "P5IMS TEST $TEST: ACK LOGOUT $gotacklogout"
echo "P5IMS TEST $TEST: INDB $indb"

score=0
if [[ $gotackcnct == 1  ]]; then (( score++ )); fi
if [[ $gotackreg == 1  ]]; then (( score++ )); fi
if [[ $gotacklogin == 1  ]]; then (( score++ )); fi
if [[ $gotacklogout == 1 ]]; then (( score++ )); fi
if [[ $indb == 1 ]]; then (( score++ )); fi

if [[ -v scoreFile ]]; then
  echo "$NAME $score/5" >> $scoreFile
fi
