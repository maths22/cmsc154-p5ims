#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=LOGIN-04.sh
GRADEFILE=CummulativeTestReport.txt
TEST=LOGIN
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
1 users:
anna
.
endofusers

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

touch $CIN1
echo "login anna" >> $CIN1
echo "sleep 6"  >> $CIN1

echo "vvvvvvvvvvvvvvvvvvvvv txtimc input:"
cat $CIN1
echo "^^^^^^^^^^^^^^^^^^^^^"

touch $CIN2
echo "sleep 3" >> $CIN2
echo "login anna" >> $CIN2
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

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT1
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT2
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv final $DB"
cat $DB
echo "^^^^^^^^^^^^^^^^^^^^^"

gotacklog=$(grep "ACK LOGIN anna" $COUT1 | wc -l)
goterror=$(grep "!!! ERROR USER_ALREADY_ACTIVE anna !!!" $COUT2 | wc -l)

echo "P5IMS TEST $TEST: ACK LOGIN $gotacklog"
echo "P5IMS TEST $TEST: ERROR USER_ALREADY_ACTIVE $goterror"

if [[ $gotacklog == 1 && $goterror == 1 ]]; then
    echo "$NAME" >> $GRADEFILE
fi
