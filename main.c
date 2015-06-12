/*
 ** cs154 Project 5 (p5ims) Instant Message Server
 ** Copyright (C)  2014,2015 University of Chicago.
 ** main.c: starter main() with command-line parsing
 **
 ** Because you are a student in cs154, you received this file through the
 ** repositories that are maintained for cs154.  This file is not licensed for
 ** any wider distribution. Specifically, you may not allow this file to be
 ** copied or downloaded by anyone who is not a current cs154 student. To do so
 ** would be a violation of copyright.
 */

#include "ims.h"

typedef struct threads threads;

struct threads {
    pthread_t t;
    threads *next;
};

void usage(const char *me) {
    fprintf(stderr, "\n");
    fprintf(stderr, "usage: %s -d dbname [-p port#] [-i saveInterval] [-v level]\n\n", me);
    fprintf(stderr, "The server will initialize from user database \"dbname\", "
            "listen for connections\n");
    fprintf(stderr, "from clients on port \"port#\" (defaults to %u), and save the user "
            "database every \"saveInterval\"\n", listenPort);
    fprintf(stderr, "seconds (defaults to %d seconds).\n", saveInterval);
    fprintf(stderr, "\nThe -v option allows some level of verbose debugging message to stdout\n");
    fprintf(stderr, "(default to %d); with -v 0 nothing should be printed to stdout.\n", verbose);
    exit(1);
}

int main(int argc, char *argv[]) {
    const char *me;
    int intrv, verb;
    unsigned short port;
    int opt; /* current option being parsed */

    me = argv[0];
    /* enstate defaults */
    intrv = saveInterval;
    verb = verbose;
    port = listenPort;

    while ((opt = getopt(argc, argv, "v:p:d:i:")) != -1)
        switch (opt) {
            case 'd':
                udbaseFilename = optarg;
                break;
            case 'p':
                if (1 != sscanf(optarg, "%hu", &port)) {
                    fprintf(stderr, "%s: couldn't parse \"%s\" as port number\n",
                            me, optarg);
                    usage(me);
                }
                break;
            case 'i':
                if (1 != sscanf(optarg, "%d", &intrv)) {
                    fprintf(stderr, "%s: couldn't parse \"%s\" as database save interval\n",
                            me, optarg);
                    usage(me);
                }
                break;
            case 'v':
                if (1 != sscanf(optarg, "%d", &verb)) {
                    fprintf(stderr, "%s: couldn't parse \"%s\" as integer verbose level\n",
                            me, optarg);
                    usage(me);
                }
                break;
            default:
                usage(me);
                break;
        }
    if (!udbaseFilename) {
        fprintf(stderr, "%s: need \"-d dbname\" option\n", argv[0]);
        usage(me);
    }
    if (intrv <= 0) {
        fprintf(stderr, "%s: need positive save interval (not %d)\n",
                me, intrv);
        usage(me);
    }
    if (verb < 0) {
        fprintf(stderr, "%s: need non-negative verbosity level (not %d)\n",
                me, verb);
        usage(me);
    }
    if (port <= 1024) {
        fprintf(stderr, "%s: need port > 1024 (not %u)\n", me, port);
        usage(me);
    }

    /* command-line options successfully parsed; assign to globals and
       start the server from the database file */
    saveInterval = intrv;
    verbose = verb;
    listenPort = port;

    if (pipe(exitfd) < 0) {
        //TODO: error handling
    }

    pthread_mutex_init(&db_lock, 0);

    impEm *iem = impEmNew();
    if (serverStart(iem)) {
        fprintf(stderr, "%s: %s server failed to start:\n", me, FAIL);
        impEmFprint(stderr, iem);
        impEmFree(iem);
        exit(1);
    }
    impEmFree(iem);

    pthread_t update_tid;
    pthread_create(&update_tid, NULL, update_thread, NULL);
    threads *tids = malloc(sizeof (threads));
    //TODO check error
    tids->t = update_tid;
    tids->next = NULL;
    threads *last = tids;

    pthread_t quit_tid;
    pthread_create(&quit_tid, NULL, quit_thread, NULL);
    threads *nexttid = malloc(sizeof (threads));
    //TODO check error
    nexttid->t = quit_tid;
    nexttid->next = NULL;
    last->next = nexttid;
    last = nexttid;

    fd_set read_fd_set;
    while (true) {
        FD_ZERO(&read_fd_set);
        FD_SET(listenfd, &read_fd_set);
        FD_SET(exitfd[0], &read_fd_set);
        if (select(FD_SETSIZE, &read_fd_set, NULL, NULL, NULL) < 0) {
            //TODO: error handling
        }
        if (FD_ISSET(exitfd[0], &read_fd_set)) {
            break;
        }
        if (FD_ISSET(listenfd, &read_fd_set)) {
            int connfd = accept(listenfd, NULL, NULL);
            if (connfd == -1) {
                //TODO conn error?
                perror("accept");
                continue;
            }

            pthread_t child;
            int *arg = malloc(sizeof (int));
            *arg = connfd;
            pthread_create(&child, NULL, connection_thread, (void *) arg);
            threads *nexttid = malloc(sizeof (threads));
            //TODO check error
            nexttid->t = child;
            nexttid->next = NULL;
            last->next = nexttid;
            last = nexttid;
        }
    }
    close(listenfd);
    close(exitfd[0]);
    close(exitfd[1]);
    pthread_cancel(update_tid);

    while (tids != NULL) {
        last = tids;
        pthread_join(tids->t, NULL);
        tids = tids->next;
        free(last);
    }

    udbaseWrite(NULL);
    freeDb(database);

    exit(0);
}
