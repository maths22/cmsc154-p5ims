#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=FRIEND_STATUS-08.sh
GRADEFILE=CummulativeTestReport.txt
TEST=FRIEND_STATUS
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
2 users:
alice
- bob requested
.
bob
- alice toanswer
.
endofusers

(sleep 20; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

mkfifo $CIN1
mkfifo $CIN2

$TXTIMC -s localhost -p $PORT < $CIN1 &> $COUT1 &
CLIAPID=$!

$TXTIMC -s localhost -p $PORT < $CIN2 &> $COUT2 &
CLIBPID=$!

echo "login alice" > $CIN1
echo "sleep 3" > $CIN1
echo "sleep 2" > $CIN2
echo "login bob" > $CIN2
echo "sleep 6" > $CIN2
echo "logout" > $CIN1
echo "sleep 3" > $CIN1

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

gotMsg1=$(grep "STATUS alice FRIEND_TOANSWER ACTIVE_NOT" $COUT2 | wc -l)
gotMsg2=$(grep "STATUS alice FRIEND_TOANSWER ACTIVE_YES" $COUT2 | wc -l)
gotMsg3=$(grep "STATUS bob FRIEND_REQUESTED ACTIVE_NOT" $COUT1 | wc -l)
gotMsg4=$(grep "STATUS bob FRIEND_REQUESTED ACTIVE_YES" $COUT1 | wc -l)

echo "P5IMS TEST $TEST: GOT MSG $gotMsg1"
echo "P5IMS TEST $TEST: GOT MSG $gotMsg3"

if [[ $gotMsg2 == 0 ]]; then
    echo "P5IMS TEST $TEST: DID GOT MSG (which is expected here) 1"
else
    echo "P5IMS TEST $TEST: DID GOT MSG (which is expected here) 0"
fi

if [[ $gotMsg4 == 0 ]]; then
    echo "P5IMS TEST $TEST: DID GOT MSG (which is expected here) 1"
else
    echo "P5IMS TEST $TEST: DID GOT MSG (which is expected here) 0"
fi

if [[ $gotMsg1 == 1 && $gotMsg2 == 0 && $gotMsg3 == 1 && $gotMsg4 == 0 ]]; then
    echo "$NAME" >> $GRADEFILE
fi
