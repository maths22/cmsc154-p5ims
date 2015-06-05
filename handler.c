/*
 ** cs154-2015 Project 5 ("p5ims") Instant Message Server
 ** basic.c: for functions that aren't called per-client-thread
 */

#include "ims.h"

/* call serverStop() upon getting "q" or "quit" on stdin */
void readQuitFromStdin(void) {
    char *line = NULL;
    size_t lsize = 0;
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
    static const char me[] = "serverStart";

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

    
    //selections borrowed from textbook source
    int optval = 1;
    struct sockaddr_in serveraddr;

    /* Create a socket descriptor */
    if ((listenfd = socket(AF_INET, SOCK_STREAM, 0)) < 0) {
        //TODO: error msg
        return 1;
    }

    /* Eliminates "Address already in use" error from bind */
    if (setsockopt(listenfd, SOL_SOCKET, SO_REUSEADDR,
            (const void *) &optval, sizeof (int)) < 0) {
        //TODO: error msg
        return 1;
    }

    /* Listenfd will be an endpoint for all requests to port
       on any IP address for this host */
    bzero((char *) &serveraddr, sizeof (serveraddr));
    serveraddr.sin_family = AF_INET;
    serveraddr.sin_addr.s_addr = htonl(INADDR_ANY);
    serveraddr.sin_port = htons((unsigned short) listenPort);
    if (bind(listenfd, (struct sockaddr *) &serveraddr, sizeof (serveraddr)) < 0) {
        //TODO: error msg
        return 1;
    }

    /* Make it a listening socket ready to accept connection requests */
    if (listen(listenfd, BACKLOG) < 0) {
        //TODO: error msg
        return 1;
    }


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
    static const char me[] = "serverStop";

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

void *quit_thread(void *arg) {
    UNUSED(arg);
    readQuitFromStdin();
    //TODO: exit on quit
    return NULL;
}
