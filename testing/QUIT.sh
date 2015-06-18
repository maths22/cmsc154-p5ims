#!/usr/bin/env bash
set -o nounset

NAME=QUIT.sh
JUNK=""
function junk {
  JUNK="$JUNK $@"
}
function cleanup {
  rm -rf $JUNK
  # make really sure nothing is left running;
  # apologies if this kills more than intended
  (killall -9 ims &> /dev/null) ||:
  (killall -9 txtimc &> /dev/null) ||:
}
trap cleanup err exit int term
function fcleanup {
  rm -f $DB; rm -f $LOG
  for ((i=1; i<=$NUMCLIENTS; i++)); do
     rm -f ${arrayCIn[i]}
  done
}

IMS=../ims
TXTIMC=../txtimc
if [[ ! -x $IMS ]]; then
  echo "P5IMS ERROR $NAME: don't see $IMS executable" >&2
  exit 1
fi
if [[ ! -x $TXTIMC ]]; then
  echo "P5IMS ERROR $NAME: don't see $TXTIMC executable" >&2
  exit 1
fi

PORT=$[ 5000 + ($RANDOM % 3000)]
NUMCLIENTS=10
PAUSE=3

for ((i=1; i<=$NUMCLIENTS; i++)); do
    arrayUsers[i]=UU_$(printf %06u $[ $RANDOM % 1000000 ])
done

DB=db-test.txt; rm -f $DB
LOG=log.txt; rm -f $LOG

for ((i=1; i<=$NUMCLIENTS; i++)); do
    arrayCIn[i]=in"$i".txt;
done

cat > $DB <<endofusers
6 users:
valgrind0
- valgrind1
.
valgrind1
- valgrind0
.
valgrind2
- valgrind3
.
valgrind3
- valgrind2
.
valgrind4
- valgrind5
.
valgrind5
- valgrind4
.
endofusers

# first see if can cleanly quit with zero clients
echo "running (sleep 3; echo quit) | valgrind --leak-check=yes --track-fds=yes $IMS -p $PORT -d $DB -i 100 &> $LOG &"
(sleep 3; echo quit) | valgrind --leak-check=yes --track-fds=yes $IMS -p $PORT -d $DB -i 100 &> $LOG &
VALPID=$!
echo "sleep 6 to wait for quit to work"
sleep 6
echo "killing ims $VALPID"
(kill -9 $VALPID &> /dev/null)||:

# 1) Inspect $LOG to see if ims exited prior to killing (valgrind will have
# done its final report) or because of the kill (no fnal report)

score=0

if grep -q "ERROR SUMMARY" $LOG; then
  if grep -q "Process terminating with default action" $LOG; then
    echo "bad: Valgrind has reported that the server has crashed, rather than quitting cleanly:"
    cat $LOG
    echo "$NAME $score/5"
    if [[ -v scoreFile ]]; then
      echo "$NAME $score/5" >> $scoreFile
    fi
    fcleanup
    exit 0
  else
    ((score++))
    echo "good ($score/5): Valgrind wrote its final report $LOG:"
    cat $LOG
  fi
else
  echo "bad: Valgrind didn't do its final report, implying that server didn't exit upon getting quit on stdin."
  cat $LOG
  echo "$NAME $score/5"
  if [[ -v scoreFile ]]; then
    echo "$NAME $score/5" >> $scoreFile
  fi
  fcleanup
  exit 0
fi

# 2) Were there memory leaks?
grep -q "All heap blocks were freed -- no leaks are possible" $LOG;
match1=$?
grep -q "definitely lost: 0 bytes in 0 blocks" $LOG;
match2=$?
if [[ $match1 -eq 0 || $match2 -eq 0 ]]; then
  ((score++))
  echo "good ($score/5): no memory leak after 1st test"
else
  echo "bad: Valgrind saw a memory leak after 1st test"
fi

# Next two tests run the server and then connects clients
for ((i=1; i<=$NUMCLIENTS; i++)); do
    CIN=${arrayCIn[i]}
    echo "register ${arrayUsers[i]}" >> $CIN
    echo "login ${arrayUsers[i]}" >> $CIN
    echo "sleep 5"  >> $CIN
    echo "vvvvvvvvvvvvvv input $CIN"
    cat $CIN
done
echo "^^^^^^^^^^^^^^"

# start server again
rm $LOG
echo "running (sleep 3; echo quit) | valgrind --leak-check=yes --track-fds=yes $IMS -p $PORT -d $DB -i 100 &> $LOG &"
(sleep 3; echo quit) | valgrind --leak-check=yes --track-fds=yes $IMS -p $PORT -d $DB -i 100 &> $LOG &
VALPID=$!

for ((i=1; i<=$NUMCLIENTS; i++)); do
    $TXTIMC -s localhost -p $PORT < ${arrayCIn[i]} &> /dev/null &
done

echo "sleep 6 to wait for ims to quit"
sleep 6
echo "killing -9 ims $VALPID"
(kill -9 $VALPID &> /dev/null)||:

# 3) check that there are no open file descriptors at exit,
# except possibly stdin, stdout, stderr.
# We have to parse valgrind output for "FILE DESCRIPTORS: N open at exit"
numOpenFds=$(grep "FILE DESCRIPTORS" $LOG | sed -r 's/([^0-9]*([0-9]*)){2}.*/\2/')
echo "Number of open file descriptors after 2nd test: $numOpenFds"
if [[ $numOpenFds -le 3 ]]; then
  score=$(echo "scale=1; $score + 1.5" | bc -l)
  echo "good ($score/5): only $numOpenFds file descriptors open"
else
  echo "bad: Valgrind saw $numOpenFds (more than 3) open file descriptors after 2nd test"
fi

# 4) Were there memory leaks? (like before)
grep -q "All heap blocks were freed -- no leaks are possible" $LOG;
match1=$?
grep -q "definitely lost: 0 bytes in 0 blocks" $LOG;
match2=$?
if [[ $match1 -eq 0 || $match2 -eq 0 ]]; then
  score=$(echo "scale=1; $score + 1.5" | bc -l)
  echo "good ($score/5): no memory leak after 2nd test"
else
  echo "Valgrind saw a memory leak after 2nd test"
fi

echo "vvvvvvvvvvvvvv log after 2nd test:"
cat $LOG
echo "^^^^^^^^^^^^^^"
echo "$NAME $score/5"

if [[ -v scoreFile ]]; then
  echo "$NAME $score/5" >> $scoreFile
fi

fcleanup
