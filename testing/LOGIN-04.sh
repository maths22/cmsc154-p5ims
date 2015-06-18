#!/usr/bin/env bash
set -o nounset

NAME=LOGIN-04.sh
TEST=LOGIN
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

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
sleep 1

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

gotacklog=$(grep "ACK LOGIN anna" $COUT1 | wc -l)
goterror=$(grep "!!! ERROR USER_ALREADY_ACTIVE anna !!!" $COUT2 | wc -l)

echo "P5IMS TEST $TEST: ACK LOGIN $gotacklog"
echo "P5IMS TEST $TEST: ERROR USER_ALREADY_ACTIVE $goterror"

score=0
if [[ $gotacklog == 1 ]]; then (( score++ )); fi
if [[ $goterror == 1 ]]; then (( score++ )); fi

if [[ -v scoreFile ]]; then
  echo "$NAME $score/2" >> $scoreFile
fi
