This testing/ directory contains test scripts for p5ims These scripts rely on
the txtimc that was pushed to you recently.  If you have modified the source
file txtimc.c then we can't promise that your test results will match the
grader's test results.

More scripts may be added and announced on piazza.  Do not modify these
scripts, since we may also push new versions of these.  Feel free to create
new tests (with different filenames).

There is currently not a mapping from these script outputs to a quantitative
grade, and there is not a one-to-one mapping between the test scripts and the
aspects of server functionality identified Section 5 "Grading" of the project
description.

These are bash scripts, so they are sequences of things that you can type and
run in your shell yourself.  You should be able to read through the script to
see what it is doing and what is looking for in the output of txtimc.

How to run a test script?

If you e.g. want to run the first test, just make sure you are in this testing/ directory
and then issue
./01-db.sh
The same for all other tests.

How do I know whether I passed a test?

You know you passed an individual test if invoking it
(1) gets you all the way to the last echo's in the script
(2) for all those echo's you see a "1" (passed), not a "0" (failed)

./01-db.sh (database could be read and written with no real change?)
output should end with:
P5IMS TEST DB: 1

./02-register.sh (can connect and register?)
output should be:
P5IMS TEST REGISTER: ACK CONNECT 1
P5IMS TEST REGISTER: ACK REGISTER 1
P5IMS TEST REGISTER: INDB 1

but if it is for example
P5IMS TEST REGISTER: ACK CONNECT 1
P5IMS TEST REGISTER: ACK REGISTER 1
P5IMS TEST REGISTER: INDB 0
that means you passed the first two subtests within this test script,
because you have 1's there, but not the last one, because there's a 0.

./03-login.sh (can register and login?)
output should end with:
P5IMS TEST LOGIN: ACK1 1
P5IMS TEST LOGIN: ACK2 1
P5IMS TEST LOGIN: ACK3 1

./04-logout.sh (can registered users login and logout?)
output should end with:
P5IMS TEST LOGOUT: CLI_1 1
P5IMS TEST LOGOUT: CLI_2 1

./05-friendadd.sh (can friendships be formed?)
output should end with:
P5IMS TEST FRIENDADD: DB 1
P5IMS TEST FRIENDADD: STATA 1
P5IMS TEST FRIENDADD: STATB 1
P5IMS TEST FRIENDADD: STATC 1
P5IMS TEST FRIENDADD: STATD 1

./06-friendrm.sh (can friendships be removed?)
output should end with:
P5IMS TEST FRIENDRM: DB 1
P5IMS TEST FRIENDRM: STATA 1
P5IMS TEST FRIENDRM: STATB 1
P5IMS TEST FRIENDRM: STATC 1
P5IMS TEST FRIENDRM: STATD 1

./07-friendstat1.sh (do friends get status messages?)
output should end with:
P5IMS TEST FRIENDSTAT1: A 1
P5IMS TEST FRIENDSTAT1: B 1

./08-friendstat2.sh (another friend status message check)
output should end with:
P5IMS TEST FRIENDSTAT2: A 1
P5IMS TEST FRIENDSTAT2: B 1

./09-friendim.sh (can friends IM each other?)
output should end with:
P5IMS TEST FRIENDIM: A 1
P5IMS TEST FRIENDIM: B 1
P5IMS TEST FRIENDIM: C 1

./10-errors.sh (are various error messages generated?)
P5IMS TEST ERRORS: A 1
P5IMS TEST ERRORS: B 1

Now you might not even get to these last echo's because of various reasons,
e.g. if the script couldn't find certain files (for example the database file
because your server doesn't yet have the code that writes the in-memory
database to the disk).  You must first make sure to get all the way to the
last echo's, plus, these echo's all have 1's at the end. Then you know you
passed the test.
