#ifndef CONNECTION_H
#define	CONNECTION_H

#include "types.h"

struct _connection_t {
    pthread_t tid;
    int socket;
    pthread_mutex_t pipeguard;
    int write;
    int read;
    dbUser_t user;
};

#endif	/* CONNECTION_H */

