#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=LOGOUT
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

DB=db-test1.txt; dieifthere $DB; junk $DB
CIN1=in1.txt; dieifthere $CIN1; junk $CIN1
CIN2=in2.txt; dieifthere $CIN2; junk $CIN2
COUT1=out1.txt; dieifthere $COUT1; junk $COUT1
COUT2=out2.txt; dieifthere $COUT2; junk $COUT2
LOG=log.txt; dieifthere $LOG; junk $LOG

function inout {
cat <<EOF
login $1
  sleep 1
 logout
  sleep 1
register $3
  sleep 1
 login $3
   sleep 1
  logout
   sleep 1
login $2
  sleep 1
 logout
  sleep 1
EOF
}

UA=UU_$(printf %06u $[ $RANDOM % 10000000 ])
UB=UU_$(printf %06u $[ $RANDOM % 10000000 ])
UC=UU_$(printf %06u $[ $RANDOM % 10000000 ])
UD=UU_$(printf %06u $[ $RANDOM % 10000000 ])

cat > $DB <<endofusers
2 users:
$UA
.
$UB
.
endofusers

inout $UA $UB $UC > $CIN1
inout $UB $UA $UD > $CIN2

PORT=$[ 5000 + ($RANDOM % 3000)]
(sleep 10; echo quit) | $IMS -p $PORT -d $DB &> $LOG &
IMSPID=$!
sleep 1


echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CIN1
echo "====================="
cat $CIN2
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT < $CIN1 &> $COUT1 &
CLI1PID=$!
$TXTIMC -s localhost -p $PORT < $CIN2 &> $COUT2 &
CLI2PID=$!
wait $CLI1PID
wait $CLI2PID

echo "vvvvvvvvvvvvvvvvvvvvv txtimc output:"
cat $COUT1
echo "====================="
cat $COUT2
echo "^^^^^^^^^^^^^^^^^^^^^"

function checkgrep {
  innA=$(grep "ACK LOGIN $UA" $1 | wc -l)
  innB=$(grep "ACK LOGIN $UB" $1 | wc -l)
  regX=$(grep "ACK REGISTER $2" $1 | wc -l)
  innX=$(grep "ACK LOGIN $2" $1 | wc -l)
  out=$(grep "ACK LOGOUT" $1 | wc -l)
  if [[ $[$innA + $innB + $regX + $innX + $out] == 7 ]]; then
    echo 1
  else
    echo "0 ($innA $innB $regX $innX $out)"
  fi
}

echo "P5IMS TEST $TEST: CLI_1 $(checkgrep $COUT1 $UC)"
echo "P5IMS TEST $TEST: CLI_2 $(checkgrep $COUT2 $UD)"
