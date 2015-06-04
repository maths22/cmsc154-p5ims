#ifndef CONNECTION_H
#define	CONNECTION_H

#include "types.h"

struct _connection_t {
    pthread_t tid;
    int connfd;
    pthread_mutex_t pipeguard;
    int writefd;
    int readfd;
    dbUser_t *user;
};

void *connection_thread(void *connfd_p);

//connection.c
void sendOp(connection_t *conn, ...);
void sendAck(connection_t *conn, ...);
void sendError(connection_t *conn, ...);
void sendStatus(connection_t *conn, ...);

//user.c
void processRegister(connection_t *conn, char *username);
void processLogin(connection_t *conn, char *username);
void processLogout(connection_t *conn);

#endif	/* CONNECTION_H */

