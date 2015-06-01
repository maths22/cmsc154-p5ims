/*
** cs154-2015 Project 5 ("p5ims") Instant Message Server
** basic.c: for functions that aren't called per-client-thread
*/

#include "ims.h"


/* call serverStop() upon getting "q" or "quit" on stdin */
void readQuitFromStdin(void) {
  char *line=NULL;
  size_t lsize=0;
  while (1) {
    ssize_t glret;
    if (verbose) {
      printf("Type \"q\" or \"quit\" to cleanly quit the server\n");
    }
    glret = getline(&line, &lsize, stdin);
    /* Ctrl-D or EOF will also break out of this loop */
    if (glret <= 0 || !strcmp("quit\n", line) || !strcmp("q\n", line)) {
      /* tell things to quit gracefully */
      free(line);
      quitting = 1;
      /* anything else to do here? */
      break;
    }

    /* ... else !strcmp("foo\n", line) to see if user typed "foo" and then
       return. You can use this to add your own additional commands here, like
       for querying globals or other aspects of server's internal state */

  }
  return;
}


int serverStart(impEm *iem) {
  static const char me[]="serverStart";

  if (verbose > 1) {
    printf("%s: hi\n", me);
  }
  if (udbaseRead(iem)) {
    impEmAdd(iem, "%s: failed to read database file \"%s\"",
             me, udbaseFilename);
    return 1;
  }
  /* immediately try writing database, so that any errors here can be
     reported as a failure of server start-up. Whether and how you do
     error handling for subsequent calls to udbaseWrite() is up to you */
  if (udbaseWrite(iem)) {
    impEmAdd(iem, "%s: failed to write database file \"%s\"",
             me, udbaseFilename);
    return 1;
  }

  /* YOUR CODE HERE:
     -- create listening file descriptor for listenPort and listen() on it
     See http://beej.us/guide/bgnet/output/html/multipage/syscalls.html
     and May 18 2015 class slides
     -- start a thread to periodically save database
     -- figure out whether looking for "quit" on stdin should be done
     in a thread that is started here, or in main.c
  */


  if (verbose) {
    printf("%s: server started on part %u from %s\n",
           me, listenPort, udbaseFilename);
  }
  if (verbose > 1) {
    printf("%s: bye\n", me);
  }
  return 0;
}

void serverStop(void) {
  static const char me[]="serverStop";

  if (verbose > 1) {
    printf("%s: hi\n", me);
  }


  /* ... YOUR CODE HERE. What needs to be done to clean up
     resources created during server execution? */


  if (verbose > 1) {
    printf("%s: bye\n", me);
  }
  return;
}

