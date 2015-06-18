#!/usr/bin/env bash
set -o nounset

NAME=ADD_RM_FRIENDS-11.sh
TEST=ADD_RM_FRIENDS
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

CNDB=../cndb
if [[ ! -x $CNDB ]]; then
  echo "P5IMS ERROR $TEST: database canonical-izer $CNDB not found" >&2
  exit 1
fi
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

for ((i=1; i<=$NUMCLIENTS; i++)); do
    arrayUsers[i]="UU_$i"
done

DB1=db-test1.txt; dieifthere $DB1; junk $DB1
DB2=db-test2.txt; dieifthere $DB2; junk $DB2
LOG=log.txt; dieifthere $LOG; junk $LOG

for ((i=1; i<=$NUMCLIENTS; i++)); do
    arrayCIn[i]=in"$i".txt; dieifthere ${arrayCIn[i]}; junk ${arrayCIn[i]}
    arrayCOut[i]=out"$i".txt; dieifthere ${arrayCOut[i]}; junk ${arrayCOut[i]}
done

echo "${NUMCLIENTS} users:" >> $DB1
for ((i=1; i<=$NUMCLIENTS; i++)); do
    echo "${arrayUsers[i]}" >> $DB1
    echo "." >> $DB1
done

cat $DB1 > $DB2

echo "=== echo starting server for 15"
(sleep 15; echo quit) | $IMS -p $PORT -d $DB1 -i $PAUSE &> $LOG &
sleep 1

for ((i=1; i<=$NUMCLIENTS; i++)); do
    CIN=${arrayCIn[i]}
    echo "vvvvvvvvvvvvvvv input $CIN (A)"
    UU=${arrayUsers[i]}
    echo "login $UU" > $CIN
    for ((j=1; j<=$NUMCLIENTS; j++)); do
      UU_OTHER=${arrayUsers[j]}
      if [[ $i -lt $j ]]; then
        echo "friend_request $UU_OTHER" >> $CIN
      fi
    done
    echo "logout $UU" >> $CIN
    echo "sleep 3"  >> $CIN
    cat $CIN
done
echo "^^^^^^^^^^^^^^^"

for ((i=1; i<=$NUMCLIENTS; i++)); do
    echo "=== starting client $i (A)"
    $TXTIMC -s localhost -p $PORT < ${arrayCIn[i]} &> ${arrayCOut[i]} &
done
sleep 5

for ((i=1; i<=$NUMCLIENTS; i++)); do
    CIN=${arrayCIn[i]}
    echo "vvvvvvvvvvvvvvv input $CIN (B)"
    UU=${arrayUsers[i]}
    echo "login $UU" > $CIN
    for ((j=1; j<=$NUMCLIENTS; j++)); do
	UU_OTHER=${arrayUsers[j]}
	if [[ $i -gt $j ]]; then
	    echo "friend_remove $UU_OTHER" >> $CIN
	fi
    done
    echo "logout $UU" >> $CIN
    echo "sleep 3"  >> $CIN
    cat $CIN
done
echo "^^^^^^^^^^^^^^^"
for ((i=1; i<=$NUMCLIENTS; i++)); do
    echo "=== starting client $i (B)"
    $TXTIMC -s localhost -p $PORT < ${arrayCIn[i]} &> ${arrayCOut[i]} &
done
sleep 5

echo "=== sleep $[$PAUSE+2] (waiting for $DB1 to be re-written)"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv got database $DB1"
cat $DB1
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv expected database $DB2"
cat $DB2
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv difference between canonical(db we got) and canonical(db we expect)"
$CNDB $DB1 $DB2 | sed 's/^.*\///'
echo "^^^^^^^^^^^^^^^^^^^^^"
! $CNDB $DB1 $DB2 > /dev/null
okay=$?
echo -n "P5IMS TEST $TEST: $okay"
if [[ 0 -eq "$okay" ]]; then
    echo " (there was a difference in the database)"
else
    echo ""
fi

if [[ -v scoreFile ]]; then
  if [[ 1 -eq "$okay" ]]; then
    echo "$NAME 1/1" >> $scoreFile
  else
    echo "$NAME 0/1" >> $scoreFile
  fi
fi
