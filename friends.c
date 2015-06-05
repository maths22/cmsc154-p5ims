#include "ims.h"

void notifyFriend(connection_t *conn, dbFriend_t *friend);

void processRequest(connection_t *conn, char *username) {
    dbUser_t *user;
    dbFriend_t *friendshipa, *friendshipb;
    if (conn->user == NULL) {
        sendError(conn, IMP_ERROR_CLIENT_NOT_BOUND, IMP_END);
    } else if ((user = lookupUser(username)) == NULL) {
        sendError(conn, IMP_ERROR_USER_DOES_NOT_EXIST, username, IMP_END);
    } else if ((friendshipa = lookupFriend(user, conn->user)) == NULL ||
            (friendshipb = lookupFriend(conn->user, user)) == NULL) {
        addFriend(conn->user, user, IMP_FRIEND_REQUESTED);
        addFriend(user, conn->user, IMP_FRIEND_TOANSWER);
        notifyFriend(conn,lookupFriend(conn->user,user));
    } else {
        if (friendshipb->status == IMP_FRIEND_REQUESTED) {
            sendError(conn, IMP_ERROR_REQUESTED_ALREADY, username, IMP_END);
        } else if (friendshipb->status == IMP_FRIEND_YES) {
            sendError(conn, IMP_ERROR_FRIEND_ALREADY, username, IMP_END);
        } else if (friendshipb->status == IMP_FRIEND_TOANSWER) {
            setFriendStatus(friendshipa, IMP_FRIEND_YES);
            setFriendStatus(friendshipb, IMP_FRIEND_YES);
            notifyFriend(conn,friendshipb);
        }
    }
}

void processRemove(connection_t *conn, char *username) {
    dbUser_t *user;
    dbFriend_t *friendshipa, *friendshipb;
    if (conn->user == NULL) {
        sendError(conn, IMP_ERROR_CLIENT_NOT_BOUND, IMP_END);
    } else if ((user = lookupUser(username)) == NULL) {
        sendError(conn, IMP_ERROR_USER_DOES_NOT_EXIST, username, IMP_END);
    } else if (user == conn->user) {
        sendError(conn, IMP_ERROR_BAD_COMMAND, IMP_END);
    } else if ((friendshipa = lookupFriend(user, conn->user)) == NULL ||
            (friendshipb = lookupFriend(conn->user, user)) == NULL) {
        sendError(conn, IMP_ERROR_NOT_FRIEND, username, IMP_END);
    } else {
        removeFriend(user, conn->user);
        removeFriend(conn->user, user);
        pthread_rwlock_wrlock(&database->lock);
        friendshipa->status = IMP_FRIEND_NOT;
        friendshipb->status = IMP_FRIEND_NOT;
        pthread_rwlock_unlock(&database->lock);
        notifyFriend(conn,friendshipb);
        free(friendshipa);
        free(friendshipb);
    }
}

void processList(connection_t *conn) {
    if (conn->user == NULL) {
        sendError(conn, IMP_ERROR_CLIENT_NOT_BOUND, IMP_END);
    } else {
        notifyFriends(conn, true, false);
    }
}

void notifyFriends(connection_t *conn, bool self, bool others) {
    pthread_rwlock_rdlock(&database->lock);
    for (size_t i = 0; i < conn->user->numFriends; i++) {
        dbFriend_t *friend = conn->user->friends[i];
        impActive_t active;
        if (friend->status == IMP_FRIEND_YES) {
            active = friend->friend->active;
            if (others) {
                sendStatus(friend->friend->thread, conn->user->name, IMP_FRIEND_YES, IMP_ACTIVE_YES, IMP_END);
            }
        } else {
            active = IMP_ACTIVE_NOT;
        }
        if (self) {
            sendStatus(conn, friend->friend->name, friend->status, active, IMP_END);
        }
    }
    pthread_rwlock_unlock(&database->lock);
}

void notifyFriend(connection_t *conn, dbFriend_t *friend) {
    impActive_t active;
    pthread_rwlock_rdlock(&database->lock);
    if (friend->status == IMP_FRIEND_YES) {
        active = friend->friend->active;
        sendStatus(friend->friend->thread, conn->user->name, IMP_FRIEND_YES, IMP_ACTIVE_YES, IMP_END);
    } else {
        active = IMP_ACTIVE_NOT;
        sendStatus(friend->friend->thread, conn->user->name, IMP_FRIEND_TOANSWER, IMP_ACTIVE_NOT, IMP_END);
    }
    sendStatus(conn, friend->friend->name, friend->status, active, IMP_END);
    pthread_rwlock_unlock(&database->lock);
}
