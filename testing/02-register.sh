#!/usr/bin/env bash
set -o errexit
set -o nounset

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
    echo "P5IMS ERROR $TEST: $1 exists already; \"rm $1\" to proceed with testing" >&2
    exit 1
 fi
}

DB=db-test.txt
CIN=in.txt
COUT=out.txt
LOG=log.txt

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
PAUSE=3

DB=db-test.txt; dieifthere $DB; junk $DB
CIN=in.txt; dieifthere $CIN; junk $CIN
COUT=out.txt; dieifthere $COUT; junk $COUT
LOG=log.txt; dieifthere $LOG; junk $LOG

cat > $DB <<endofusers
5 users:
alice
- elian
- bob requested
- carol
.
bob
- alice toanswer
- carol
.
carol
- bob
- alice
.
david
.
elian
- alice
.
endofusers

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

touch $CIN
echo "register $UU" >> $CIN
echo "sleep 3"  >> $CIN

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

gotackcnct=$(grep "ACK CONNECT" $COUT | wc -l)
gotack=$(grep "ACK REGISTER $UU" $COUT | wc -l)
indb=$(grep $UU $DB | wc -l)

echo "P5IMS TEST $TEST: ACK CONNECT $gotackcnct"
echo "P5IMS TEST $TEST: ACK REGISTER $gotack"
echo "P5IMS TEST $TEST: INDB $indb"
