#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=FRIENDIM
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
CINC=inC.txt; dieifthere $CINC; junk $CINC
COUTA=outA.txt; dieifthere $COUTA; junk $COUTA
COUTB=outB.txt; dieifthere $COUTB; junk $COUTB
COUTC=outC.txt; dieifthere $COUTC; junk $COUTC
WANTA=wantA.txt; dieifthere $WANTA; junk $WANTA
WANTB=wantB.txt; dieifthere $WANTB; junk $WANTB
WANTC=wantC.txt; dieifthere $WANTC; junk $WANTC
GOTA=gotA.txt; dieifthere $GOTA; junk $GOTA
GOTB=gotB.txt; dieifthere $GOTB; junk $GOTB
GOTC=gotC.txt; dieifthere $GOTC; junk $GOTC
LOG=log.txt; dieifthere $LOG; junk $LOG

UA=UU_$(printf %04u $[ $RANDOM % 10000 ])
UB=UU_$(printf %04u $[ $RANDOM % 10000 ])
UC=UU_$(printf %04u $[ $RANDOM % 10000 ])
UD=UU_$(printf %04u $[ $RANDOM % 10000 ])

cat > $DB <<EOF
3 users:
$UA
- $UB
.
$UB
- $UA
.
$UC
.
EOF

msg1=$(cat /dev/urandom | tr -dc [:graph:] | head -c70)
msg2=$(cat /dev/urandom | tr -dc [:graph:] | head -c70)
msg3=$(cat /dev/urandom | tr -dc [:graph:] | head -c70)
msg4=$(cat /dev/urandom | tr -dc [:graph:] | head -c70)
msg5=$(cat /dev/urandom | tr -dc [:graph:] | head -c70)

# (stitching together the commands here with the expected results in WANTA)
# Time: command      --> expected result
#                        (explanation)
#    0: login $UA    --> "2 2 $UA" (ACK LOGIN $UA)
#                    --> *** friend $UB: ACTIVE_NOT ***
#                        ($UA is not logged in)
#    1:              --> *** friend $UB: ACTIVE_YES ***
#                        ($UA just logged in)
#    2: im $UB $msg1 --> "2 7 $UB" (ACK IM $UB)
#    4:              --> *** $UB says "$msg3" ***
#                        (IM from $UB)
#    5:              --> *** friend $UB: ACTIVE_NOT ***
#                        ($UB just logged out)
#    6: im $UC $msg4 --> !!! ERROR NOT_FRIEND $UC !!!
#    7: im $UD $msg5 --> !!! ERROR USER_DOES_NOT_EXIST !!!
#    8: logout       --> "2 3" (ACK LOGOUT)
cat > $CINA <<EOF
login $UA
  sleep 2
im $UB $msg1
  sleep 4
im $UC $msg4
  sleep 1
im $UD $msg5
  sleep 1
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command      --> expected result
#                        (explanation)
#    1: login $UB    --> "2 2 $UB" (ACK LOGIN $UB)
#                    --> *** friend $UA: ACTIVE_YES ***
#                        ($UA is logged in already)
#    2:              --> *** $UA says "$msg1" ***
#                        (IM from $UA)
#    3: im $UC $msg2 --> !!! ERROR NOT_FRIEND $UC !!!
#    4: im $UA $msg3 --> "2 7 $UA" (ACK IM $UA)
#    5: logout       --> "2 3" (ACK LOGOUT)
cat > $CINB <<EOF
  sleep 1
login $UB
  sleep 2
im $UC $msg2
  sleep 1
im $UA $msg3
  sleep 1
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTC)
# Time: command      --> expected result
#                        (explanation)
#    0: login $UC    --> "2 2 $UC" (ACK LOGIN $UC)
#    4: logout       --> "2 3" (ACK LOGOUT)
cat > $CINC <<EOF
login $UC
  sleep 4
logout
  sleep 1
EOF

PORT=$[ 5000 + ($RANDOM % 3000)]
(sleep 10; echo quit) | $IMS -p $PORT -d $DB &> $LOG &
IMSPID=$!
sleep 1

echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CINA
echo "====================="
cat $CINB
echo "====================="
cat $CINC
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT < $CINA &> $COUTA &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT < $CINB &> $COUTB &
CLIBPID=$!
$TXTIMC -s localhost -p $PORT < $CINC &> $COUTC &
CLICPID=$!
wait $CLIAPID
wait $CLIBPID
wait $CLICPID

cat > $WANTA <<EOF
"2 8" (ACK CONNECT)
"2 2 $UA" (ACK LOGIN $UA)
 *** friend $UB: ACTIVE_NOT ***
 *** friend $UB: ACTIVE_YES ***
"2 7 $UB" (ACK IM $UB)
 *** $UB says "$msg3" ***
 *** friend $UB: ACTIVE_NOT ***
 !!! ERROR NOT_FRIEND $UC !!!
 !!! ERROR USER_DOES_NOT_EXIST !!!
"2 3" (ACK LOGOUT)
EOF

cat > $WANTB <<EOF
"2 8" (ACK CONNECT)
"2 2 $UB" (ACK LOGIN $UB)
 *** friend $UA: ACTIVE_YES ***
 *** $UA says "$msg1" ***
 !!! ERROR NOT_FRIEND $UC !!!
"2 7 $UA" (ACK IM $UA)
"2 3" (ACK LOGOUT)
EOF

cat > $WANTC <<EOF
"2 8" (ACK CONNECT)
"2 2 $UC" (ACK LOGIN $UC)
"2 3" (ACK LOGOUT)
EOF

(grep "[\*\!A][\*\!C][\*\!K] " $COUTA | sed s/server\ response\ [0-9]:\ //g > $GOTA ||:)
(grep "[\*\!A][\*\!C][\*\!K] " $COUTB | sed s/server\ response\ [0-9]:\ //g > $GOTB ||:)
(grep "[\*\!A][\*\!C][\*\!K] " $COUTC | sed s/server\ response\ [0-9]:\ //g > $GOTC ||:)

echo "vvvvvvvvvvvvvvvvvvvvv wanted status+error messages:"
cat $WANTA
echo "====================="
cat $WANTB
echo "====================="
cat $WANTC
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv got status+error messages:"
cat $GOTA
echo "====================="
cat $GOTB
echo "====================="
cat $GOTC
echo "^^^^^^^^^^^^^^^^^^^^^"

! diff $WANTA $GOTA > /dev/null
okayA=$?
! diff $WANTB $GOTB > /dev/null
okayB=$?
! diff $WANTC $GOTC > /dev/null
okayC=$?

echo P5IMS TEST $TEST: A $okayA
echo P5IMS TEST $TEST: B $okayB
echo P5IMS TEST $TEST: C $okayC
