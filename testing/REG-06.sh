#!/usr/bin/env bash
set -o errexit
set -o nounset

NAME=REG-06.sh
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
NUMCLIENTS=10
PAUSE=3

for ((i=1; i<=$NUMCLIENTS; i++))
do
    arrayUsers[i]=UU_$(printf %06u $[ $RANDOM % 1000000 ])
done

DB=db-test.txt; dieifthere $DB; junk $DB
LOG=log.txt; dieifthere $LOG; junk $LOG

for ((i=1; i<=$NUMCLIENTS; i++))
do
    arrayCIn[i]=in"$i".txt; dieifthere ${arrayCIn[i]}; junk ${arrayCIn[i]}
    arrayCOut[i]=out"$i".txt; dieifthere ${arrayCOut[i]}; junk ${arrayCOut[i]}
done

cat > $DB <<endofusers
0 users:
endofusers

(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1

for ((i=1; i<=$NUMCLIENTS; i++))
do
    CIN=${arrayCIn[i]}
    echo "register ${arrayUsers[i]}" >> $CIN
    echo "sleep 3"  >> $CIN

    COUT=${arrayCOut[i]}
    $TXTIMC -s localhost -p $PORT < $CIN &> $COUT &
    arrayPIDs[i]=$!
done

for ((i=1; i<=$NUMCLIENTS; i++))
do
    wait ${arrayPIDs[i]}
done

echo "=== sleep $[$PAUSE+2] (waiting for $DB to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv final $DB"
cat $DB
echo "^^^^^^^^^^^^^^^^^^^^^"

passed=1
for ((i=1; i<=$NUMCLIENTS; i++))
do
    inDB=$(grep "${arrayUsers[i]}" $DB | wc -l)
    if [[ $inDB != 1 ]]; then
	passed=0
	break
    fi
done

echo "P5IMS TEST $TEST: INDB $passed"

if [[ $passed == 1 ]]; then
    echo "$NAME" >> $GRADEFILE
fi
