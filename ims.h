/*
 ** cs154-2015 Project 5 ("p5ims") Instant Message Server
 ** ims.h: header file
 */

#ifndef IMS_INCLUDED
#define IMS_INCLUDED

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h> /* inet_ntop */
#include <sys/types.h> /* getaddrinfo */
#include <sys/socket.h>  /* recv, send, getaddrinfo */
#include <netdb.h> /* getaddrinfo */
#include <unistd.h> /* sleep */
#include <pthread.h>
#include <errno.h>
#include <assert.h>
#include <ctype.h>    /* for isspace() etc */

#include "imp.h"  /* the protocol library */

/* the string that you should include in error messages to stderr
   documenting how starting the server failed */
#define FAIL "SERVER_INIT_FAIL"

/* YOUR CODE HERE
   ... declaration of structs or other data types you design ... */

/* For each source file (except main.c), declare here (with "extern") the
symbols (the variables and the functions) that it defines, so that #include
"ims.h" at the top of the source allows every source file to use the symbols
from every other source file */

/* globals.c: global variables */
/* this information is stored in globals because it could be awkward to create
   a container for it to be passed to all functions that need to know it */
extern int verbose; /* how much verbose debugging messages to print
                            during operation */
extern int saveInterval; /* interval, in seconds, with which to save
                            user database */
extern unsigned short listenPort; /* port to listen on */
extern const char *udbaseFilename; /* filename for user database */
extern int quitting; /* flag to say (by being non-zero) that its time
			    to shut things down and quit cleanly. This is
			    set by readQuitFromStdin() */
/* add more globals as you see fit */

/* udbase.c: for handling the user database, on disk and in memory */
/* possible place to declare globals for in-memory user database */
/* read user database into memory */
extern int udbaseRead(impEm *iem);
extern int udbaseWrite(impEm *iem);

/* basic.c: for high-level and utility functions */
/* if "quit" is typed on on stdin, call serverStop() */
extern void readQuitFromStdin(void);
/* start the server */
extern int serverStart(impEm *iem);
/* stop the server and clean up dynamically allocated resources */
extern void serverStop(void);



#endif /* IMS_INCLUDED */
