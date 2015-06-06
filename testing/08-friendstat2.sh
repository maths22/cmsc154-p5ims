#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=FRIENDSTAT2
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

DB=db-test.txt;     dieifthere $DB;   junk $DB
CINA=inA.txt; dieifthere $CINA; junk $CINA
CINB=inB.txt; dieifthere $CINB; junk $CINB
COUTA=outA.txt; dieifthere $COUTA; junk $COUTA
COUTB=outB.txt; dieifthere $COUTB; junk $COUTB
WANTA=wantA.txt; dieifthere $WANTA; junk $WANTA
WANTB=wantB.txt; dieifthere $WANTB; junk $WANTB
GOTA=gotA.txt; dieifthere $GOTA; junk $GOTA
GOTB=gotB.txt; dieifthere $GOTB; junk $GOTB
LOG=log.txt; dieifthere $LOG; junk $LOG

UA=UU_$(printf %04u $[ $RANDOM % 10000 ])
UB=UU_$(printf %04u $[ $RANDOM % 10000 ])

cat > $DB <<EOF
2 users:
$UA
- $UB
.
$UB
- $UA
.
EOF

# (stitching together the commands here with the expected results in WANTA)
# Time: command    --> expected result
#                      (explanation)
#    0: login $UA  --> *** friend $UB: ACTIVE_NOT ***
#                      (because friend $UB is not logged in)
#    1:            -->  *** friend $UB: ACTIVE_YES ***
#                      (because friend $UB just logged in)
#    2: list       -->  *** friend $UB: ACTIVE_YES ***
#                      (output of list)
#    3: logout
cat > $CINA <<EOF
login $UA
  sleep 2
list
  sleep 1
logout
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command    --> expected result
#                      (explanation)
#    1: login $UB  --> *** friend $UA: ACTIVE_YES ***
#                      (because friend $UA is already logged in)
#    3:            --> *** friend $UA: ACTIVE_NOT ***
#                      (because $UA just logged out)
#    4: list       --> *** friend $UA: ACTIVE_NOT ***
#                      (because $UA logged out at time 3)
#    5: logout
cat > $CINB <<EOF
  sleep 1
login $UB
  sleep 3
list
  sleep 1
logout
EOF

PORT=$[ 5000 + ($RANDOM % 3000)]
(sleep 10; echo quit) | $IMS -p $PORT -d $DB &> $LOG &
IMSPID=$!
sleep 1


echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CINA
echo "====================="
cat $CINB
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT -q < $CINA &> $COUTA &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT -q < $CINB &> $COUTB &
CLIBPID=$!
wait $CLIAPID
wait $CLIBPID

cat > $WANTA <<EOF
 *** friend $UB: ACTIVE_NOT ***
 *** friend $UB: ACTIVE_YES ***
 *** friend $UB: ACTIVE_YES ***
EOF

cat > $WANTB <<EOF
 *** friend $UA: ACTIVE_YES ***
 *** friend $UA: ACTIVE_NOT ***
 *** friend $UA: ACTIVE_NOT ***
EOF

(grep "^ \*\*\* " $COUTA > $GOTA ||:)
(grep "^ \*\*\* " $COUTB > $GOTB ||:)

echo "vvvvvvvvvvvvvvvvvvvvv wanted status messages:"
cat $WANTA
echo "====================="
cat $WANTB
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv got status messages:"
cat $GOTA
echo "====================="
cat $GOTB
echo "^^^^^^^^^^^^^^^^^^^^^"

! diff $WANTA $GOTA > /dev/null
okayA=$?
! diff $WANTB $GOTB > /dev/null
okayB=$?


echo P5IMS TEST $TEST: A $okayA
echo P5IMS TEST $TEST: B $okayB
