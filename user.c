#include "ims.h"

bool _isValidUsername(const char *str);

void processLogin(connection_t *conn, char *username) {
    dbUser_t *user;
    if (conn->user != NULL) {
        sendError(conn, IMP_ERROR_CLIENT_BOUND, conn->user->name, IMP_END);
    } else if ((user = lookupUser(username)) == NULL) {
        sendError(conn, IMP_ERROR_USER_DOES_NOT_EXIST, IMP_END);
    } else if (user->active == IMP_ACTIVE_YES) {
        sendError(conn, IMP_ERROR_USER_ALREADY_ACTIVE, username, IMP_END);
    } else {
        conn->user = user;
        setUserStatus(conn->user, IMP_ACTIVE_YES, conn);
        sendAck(conn, IMP_OP_LOGIN, conn->user->name, IMP_END);
        notifyFriends(conn, true, true);
    }
}

void processLogout(connection_t *conn) {
    if (conn->user == NULL) {
        sendError(conn, IMP_ERROR_CLIENT_NOT_BOUND, IMP_END);
    } else {
        setUserStatus(conn->user, IMP_ACTIVE_NOT, NULL);
        sendAck(conn, IMP_OP_LOGOUT, IMP_END);
        notifyFriends(conn, false, true);
        conn->user = NULL;
    }
}

void processRegister(connection_t *conn, char *username) {
    if (conn->user != NULL) {
        sendError(conn, IMP_ERROR_CLIENT_BOUND, conn->user->name, IMP_END);
    } else if (!_isValidUsername(username)) {
        sendError(conn, IMP_ERROR_BAD_COMMAND, IMP_END);
    } else if (lookupUser(username)) {
        sendError(conn, IMP_ERROR_USER_EXISTS, username, IMP_END);
    } else {
        addUser(username);
        sendAck(conn, IMP_OP_REGISTER, username, IMP_END);
    }
}

bool _isValidUsername(const char *str) {
    if(strlen(str) > IMP_NAME_MAXLEN) {
        return false;
    }
    for (size_t i = 0; i < strlen(str); i++) {
        if (isspace(str[i]) || !isprint(str[i])) {
            return false;
        }
    }
    return true;
}
