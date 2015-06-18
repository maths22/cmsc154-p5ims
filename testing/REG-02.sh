#!/usr/bin/env bash
set -o nounset

NAME=REG-02.sh
TEST=REGISTER
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

DB=db-test.txt

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
UU1=WAYTOOOOOLONGUSERNAME
UU2=JUSTALLOOWEDUSERNAME
PAUSE=3

DB=db-test.txt; dieifthere $DB; junk $DB
CIN1=in1.txt; dieifthere $CIN1; junk $CIN1
COUT1=out1.txt; dieifthere $COUT1; junk $COUT1
CIN2=in2.txt; dieifthere $CIN2; junk $CIN2
COUT2=out2.txt; dieifthere $COUT2; junk $COUT2
LOG=log.txt; dieifthere $LOG; junk $LOG

cat > $DB <<endofusers
0 users:
endofusers

touch $CIN1
echo "register $UU1" >> $CIN1
echo "sleep 3"  >> $CIN1

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN1
echo "^^^^^^^^^^^^^^^^^^^^^"

touch $CIN2
echo "register $UU2" >> $CIN2
echo "sleep 3"  >> $CIN2

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN2
echo "^^^^^^^^^^^^^^^^^^^^^"

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
sleep 1

$TXTIMC -s localhost -p $PORT < $CIN1 &> $COUT1 &
CLI1PID=$!
$TXTIMC -s localhost -p $PORT < $CIN2 &> $COUT2 &
CLI2PID=$!
wait $CLI1PID
wait $CLI2PID

echo "=== sleep $[$PAUSE+2] (waiting for $DB to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT1
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT2
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv final $DB"
cat $DB
echo "^^^^^^^^^^^^^^^^^^^^^"

regAck=$(grep "ACK REGISTER $UU2" $COUT2 | wc -l)
errorTooLong=$(grep "!!! ERROR BAD_COMMAND !!!" $COUT1 | wc -l)
indb=$(grep $UU2 $DB | wc -l)

echo "P5IMS TEST $TEST: ACK REGISTER $regAck"
echo "P5IMS TEST $TEST: ERROR_BAD_COMMAND $errorTooLong"
echo "P5IMS TEST $TEST: INDB $indb"

score=0
if [[ $regAck == 1 ]]; then (( score++ )); fi
if [[ $errorTooLong == 1 ]]; then (( score++ )); fi
if [[ $indb == 1 ]]; then (( score++ )); fi

if [[ -v scoreFile ]]; then
  echo "$NAME $score/3" >> $scoreFile
fi
