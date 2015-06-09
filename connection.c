#include "ims.h"

extern impMsg *_impMsgNew_va(impEm *iem, impMsgType_t mt, va_list args);

void _handleOpMsg(connection_t *conn, impMsgOp *msg);

void *connection_thread(void *connfd_p) {
    char me[] = "connection_thread";

    int connfd = *(int*) connfd_p;
    free(connfd_p);
    connection_t *data = malloc(sizeof (connection_t));
    data->connfd = connfd;
    data->user = NULL;
    int fds[2];
    if (pipe(fds)) {
        //TODO: handle error
    }
    data->readfd = fds[0];
    data->writefd = fds[1];
    pthread_mutex_init(&data->pipeguard, 0);
    data->tid = pthread_self();
    sendAck(data, IMP_OP_CONNECT, IMP_END);
    char buf[BUFF_SIZE];
    char *cmdstr;
    char *strtok_nl;
    char where[BUFF_SIZE];
    int cnt;
    fd_set read_fd_set;
    while (true) {
        bzero(buf, BUFF_SIZE);

        FD_ZERO(&read_fd_set);
        FD_SET(data->readfd, &read_fd_set);
        FD_SET(connfd, &read_fd_set);
        FD_SET(exitfd[0], &read_fd_set);

        if (select(FD_SETSIZE, &read_fd_set, NULL, NULL, NULL) < 0) {
            //TODO: error handling
        }

        if (FD_ISSET(exitfd[0], &read_fd_set)) {
            break;
        }

        if (FD_ISSET(connfd, &read_fd_set)) {
            //selections borrowed from txtimc.c
            cnt = recv(connfd, buf, BUFF_SIZE, 0);
            if (cnt < 0) {
                sprintf(where, "%s: recv() failed (readBytes=%d)", me, (int) cnt);
                perror(where);
                processLogout(data);
                break;
            }
            if (!cnt) {
                fprintf(stderr, "%s: client closed connection\n", me);
                if (close(connfd)) {
                    sprintf(where, "%s: close() after server disconnect", me);
                    perror(where);
                }
                processLogout(data);
                break;
            }
            //TODO: split protocol strings
            cmdstr = strtok_r(buf, "\n", &strtok_nl);
            if (cmdstr != NULL) {
                do {

                    impEm *iem = impEmNew();
                    impMsg *ret = impStrToMsg(iem, cmdstr);
                    if (!ret) {
                        impEmFprint(stderr, iem);
                        impEmFree(iem);
                        sendError(data, IMP_ERROR_BAD_COMMAND, IMP_END);
                        continue;
                    }
                    impEmFree(iem);

                    impMsgOp *opMsg;
                    switch (ret->mt) {
                        case IMP_MSG_TYPE_OP:
                            opMsg = (impMsgOp*) ret;
                            pthread_mutex_lock(&db_lock);
                            _handleOpMsg(data, opMsg);
                            pthread_mutex_unlock(&db_lock);
                            break;
                        default:
                            sendError(data, IMP_ERROR_BAD_COMMAND, IMP_END);
                            break;
                    }

                    impMsgFree(ret);
                } while ((cmdstr = strtok_r(NULL, "\n", &strtok_nl)));

            } else {
                sendError(data, IMP_ERROR_BAD_COMMAND, IMP_END);
            }
        }

        if (FD_ISSET(data->readfd, &read_fd_set)) {
            pthread_mutex_lock(&data->pipeguard);
            struct timeval timeout;
            timeout.tv_sec = 0;
            timeout.tv_usec = 0;
            FD_ZERO(&read_fd_set);
            FD_SET(data->readfd, &read_fd_set);
            while (select(FD_SETSIZE, &read_fd_set, NULL, NULL, &timeout) > 0) {
                cnt = read(data->readfd, buf, BUFF_SIZE);
                while (cnt > 0) {
                    int sent = send(connfd, buf, cnt, 0);
                    if (sent < 0) {
                        //TODO: error
                    }
                    cnt -= sent;
                }
            }
            pthread_mutex_unlock(&data->pipeguard);
        }

    }
    free(data);
    pthread_exit(0);
}

void _handleOpMsg(connection_t *conn, impMsgOp * msg) {
    if (verbose) {
        printf("OP received: %s\n", impOpStr(msg->op));
    }
    switch (msg->op) {
        case IMP_OP_LOGIN:
            processLogin(conn, msg->userName);
            break;
        case IMP_OP_LOGOUT:
            processLogout(conn);
            break;
        case IMP_OP_REGISTER:
            processRegister(conn, msg->userName);
            break;
        case IMP_OP_FRIEND_REQUEST:
            processRequest(conn, msg->userName);
            break;
        case IMP_OP_FRIEND_REMOVE:
            processRemove(conn, msg->userName);
            break;
        case IMP_OP_FRIEND_LIST:
            processList(conn);
            break;
        case IMP_OP_IM:
            processIM(conn, msg->userName, msg->IM);
            break;
        default:
            sendError(conn, IMP_ERROR_BAD_COMMAND, IMP_END);
            break;
    }
}

void _sendStr(connection_t *conn, char *str) {
    pthread_mutex_lock(&conn->pipeguard);
    if (write(conn->writefd, str, strlen(str)) < 0) {
        //TODO report error
    }
    pthread_mutex_unlock(&conn->pipeguard);
}

void _sendMsg_va(connection_t *conn, impMsgType_t type, va_list args) {
    if (conn != NULL) {
        impMsg *msg = _impMsgNew_va(NULL, type, args);
        char *msgstr = impMsgToStr(NULL, msg);
        impMsgFree(msg);
        _sendStr(conn, msgstr);
        free(msgstr);
    }
}

void sendError(connection_t *conn, ...) {
    va_list args;
    va_start(args, conn);
    _sendMsg_va(conn, IMP_MSG_TYPE_ERROR, args);
    va_end(args);
}

void sendAck(connection_t *conn, ...) {
    va_list args;
    va_start(args, conn);
    _sendMsg_va(conn, IMP_MSG_TYPE_ACK, args);
    va_end(args);
}

void sendStatus(connection_t *conn, ...) {
    va_list args;
    va_start(args, conn);
    _sendMsg_va(conn, IMP_MSG_TYPE_STATUS, args);
    va_end(args);
}

void sendOp(connection_t *conn, ...) {
    va_list args;
    va_start(args, conn);
    _sendMsg_va(conn, IMP_MSG_TYPE_OP, args);
    va_end(args);
}
