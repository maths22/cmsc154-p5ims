#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=FRIENDSTAT1
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
.
$UB
.
EOF

# (stitching together the commands here with the expected results in WANTA)
# Time: command        --> expected result
#                          (explanation)
#    0: login $UA
#    1: req $UB        --> *** $UB: FRIEND_REQUESTED ***
#    3: logout
#    6: login $UA      --> *** friend $UB: ACTIVE_NOT ***
#    7: logout
cat > $CINA <<EOF
login $UA
  sleep 1
req $UB
  sleep 2
logout
  sleep 3
login $UA
  sleep 1
logout
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command        --> expected result
#                          (explanation)
#    2: login $UA      --> *** $UA: FRIEND_TOANSWER ***
#                          (we see the friend request from $UA upon login)
#    4: req $UA        --> *** friend $UA: ACTIVE_NOT ***
#                          (now that we're friends with $UA, we learn whether
#                           $UA is logged in: no, because of logout at time 3)
#    5: logout
cat > $CINB <<EOF
  sleep 2
login $UB
  sleep 2
req $UA
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
 *** $UB: FRIEND_REQUESTED ***
 *** friend $UB: ACTIVE_NOT ***
EOF

cat > $WANTB <<EOF
 *** $UA: FRIEND_TOANSWER ***
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
