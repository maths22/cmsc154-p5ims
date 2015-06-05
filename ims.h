/*
 ** cs154-2015 Project 5 ("p5ims") Instant Message Server
 ** ims.h: header file
 */

#ifndef IMS_INCLUDED
#define IMS_INCLUDED

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
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

#include "const.h"
#include "udbase.h"
#include "globals.h"
#include "connection.h"
#include "handler.h"

#define UNUSED(x) (void)(x)

#endif /* IMS_INCLUDED */
