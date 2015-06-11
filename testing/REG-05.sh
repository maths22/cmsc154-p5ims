#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=REG-05.sh
GRADEFILE=CummulativeTestReport.txt
TEST=REGISTER
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

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

touch $CIN1
echo "register alice" >> $CIN1
echo "sleep 3"  >> $CIN1

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN1
echo "^^^^^^^^^^^^^^^^^^^^^"

touch $CIN2
echo "register bob" >> $CIN2
echo "sleep 3"  >> $CIN2

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN2
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT < $CIN1 &> $COUT1 &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT < $CIN2 &> $COUT2 &
CLIBPID=$!
wait $CLIAPID
wait $CLIBPID

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

gotack1=$(grep "ACK REGISTER alice" $COUT1 | wc -l)
gotack2=$(grep "ACK REGISTER bob" $COUT2 | wc -l)
if [[ $gotack1 == 1 && $gotack2 == 1 ]]; then
    echo "P5IMS TEST $TEST: ACK REGISTER 1"
else
    echo "P5IMS TEST $TEST: ACK REGISTER 0"
fi

indb1=$(grep "alice" $DB | wc -l)
indb2=$(grep "bob" $DB | wc -l)
if [[ $indb1 == 1 && $indb2 == 1 ]]; then
    echo "P5IMS TEST $TEST: INDB 1"
else
    echo "P5IMS TEST $TEST: INDB 0"
fi

if [[ $gotack1 == 1 && $gotack2 == 1 && $indb1 == 1 && $indb2 == 1 ]]; then
    echo "$NAME" >> $GRADEFILE
fi
