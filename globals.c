/*
** cs154-2015 Project 5 ("p5ims") Instant Message Server
** misc.c: miscellaneous things
*/

#include "ims.h"

int verbose = 1;
int saveInterval = 10;
unsigned short listenPort = 15400;
const char *udbaseFilename = NULL;
int quitting = 0;

