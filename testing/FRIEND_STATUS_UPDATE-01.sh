#!/usr/bin/env bash
set -o nounset

NAME=FRIEND_STATUS_UPDATE-01.sh
TEST=FRIEND_STATUS_UPDATE
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
2 users:
alice
.
bob
.
endofusers

cat > $CIN1 <<EOF
login alice
sleep 3
friend_request bob
sleep 3
EOF
cat > $CIN2 <<EOF
login bob
sleep 6
EOF

echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CIN1
echo "==========="
cat $CIN2
echo "^^^^^^^^^^^^^^^^^^^^^"

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
sleep 1

$TXTIMC -s localhost -p $PORT < $CIN1 &> $COUT1 &
$TXTIMC -s localhost -p $PORT < $CIN2 &> $COUT2 &
sleep 6

echo "=== sleep $[$PAUSE+2] (waiting for $DB to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv txtimc outputs:"
cat $COUT1
echo "==========="
cat $COUT2
echo "^^^^^^^^^^^^^^^^^^^^^"

gotMsg1=$(grep "STATUS alice FRIEND_TOANSWER ACTIVE_NOT" $COUT2 | wc -l)
gotMsg2=$(grep "STATUS bob FRIEND_REQUESTED ACTIVE_NOT" $COUT1 | wc -l)

if [[ $gotMsg1 == 1 && $gotMsg2 == 1 ]]; then
    echo "P5IMS TEST $TEST: GOT MSGS 1"
else
    echo "P5IMS TEST $TEST: GOT MSGS 0"
fi

score=0
if [[ $gotMsg1 == 1 ]]; then (( score++ )); fi
if [[ $gotMsg2 == 1 ]]; then (( score++ )); fi

if [[ -v scoreFile ]]; then
  echo "$NAME $score/2" >> $scoreFile
fi
