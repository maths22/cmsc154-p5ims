/*
 ** cs154-2015 Project 5 ("p5ims") Instant Message Server
 ** udbase.c: for reading and writing the user database
 */

#include "ims.h"

db_t *newDB() {
    db_t *ret = malloc(sizeof (db_t));
    //TODO: handle error
    ret->_memsize = DB_INIT_SIZE;
    ret->numUsers = 0;
    ret->users = calloc(ret->_memsize, sizeof (dbUser_t*));
    //TODO: handle error
    pthread_rwlock_init(&ret->lock,0);
    return ret;
}

void addUser(char *username) {
    pthread_rwlock_wrlock(&database->lock);
    if (database->numUsers + 1 > database->_memsize) {
        database->_memsize *= 2;
        database->users = realloc(database->users, database->_memsize * sizeof (dbUser_t*));
        //TODO: error check
    }

    dbUser_t *user = malloc(sizeof (dbUser_t));
    //TODO: error check
    user->_memsize = DB_INIT_SIZE;
    user->friends = calloc(user->_memsize, sizeof (dbFriend_t*));
    //TODO: error check
    user->numFriends = 0;
    user->thread = NULL;
    user->active = IMP_ACTIVE_NOT;
    user->name = strdup(username);
    //TODO: error check

    database->users[database->numUsers] = user;
    database->numUsers++;
    pthread_rwlock_unlock(&database->lock);
}

void addFriend(dbUser_t *user, dbUser_t *friend, impFriend_t status) {
    pthread_rwlock_wrlock(&database->lock);
    if (user->numFriends + 1 > user->_memsize) {
        user->_memsize *= 2;
        user->friends = realloc(user->friends, user->_memsize * sizeof (dbFriend_t*));
        //TODO: error check
    }

    dbFriend_t *newfriend = malloc(sizeof (dbFriend_t));
    //TODO: error check
    newfriend->friend = friend;
    newfriend->status = status;
    //TODO: error check

    user->friends[user->numFriends] = newfriend;
    user->numFriends++;
    pthread_rwlock_unlock(&database->lock);
}

//friend must be a friend of user, otherwise behavior is undefined

void removeFriend(dbUser_t *user, dbUser_t *friend) {
    pthread_rwlock_wrlock(&database->lock);

    int i;
    for (i = 0; i < user->numFriends; i++) {
        if (user->friends[i]->friend == friend) {
            break;
        }
    }

    free(user->friends[i]);
    memmove(&user->friends[i], &user->friends[i + 1], sizeof (dbFriend_t*) * (user->numFriends - i));
    user->numFriends--;

    pthread_rwlock_unlock(&database->lock);
}

dbUser_t *lookupUser(char *username) {
    dbUser_t *ret = NULL;
    pthread_rwlock_rdlock(&database->lock);
    for (int i = 0; i < database->numUsers; i++) {
        if (strcmp(database->users[i]->name, username) == 0) {
            ret = database->users[i];
        }
    }
    pthread_rwlock_unlock(&database->lock);
    return ret;
}

dbFriend_t *lookupFriend(dbUser_t *user, dbUser_t *friend) {
    dbFriend_t *ret = NULL;
    pthread_rwlock_rdlock(&database->lock);
    for (int i = 0; i < user->numFriends; i++) {
        if (user->friends[i]->friend == friend) {
            ret = user->friends[i];
        }
    }
    pthread_rwlock_unlock(&database->lock);
    return ret;
}

void setFriendStatus(dbFriend_t *friend, impFriend_t status) {
    pthread_rwlock_wrlock(&database->lock);
    friend->status = status;
    pthread_rwlock_unlock(&database->lock);
}

void setUserStatus(dbUser_t *user, impActive_t active, connection_t *thread) {
    pthread_rwlock_wrlock(&database->lock);
    user->active = active;
    user->thread = thread;
    pthread_rwlock_unlock(&database->lock);
}

/* your in-memory representation of user database can be pointed to by some
   global variables, declared in ims.h, defined here, and initialized by
   udbaseRead below.  When server is running with multiple threads, access to
   these globals should be guarded by a mutex. */

int udbaseRead(impEm *iem) {
    static const char me[] = "udbaseRead";
    FILE *file;

    file = fopen(udbaseFilename, "r");
    if (!file) {
        impEmAdd(iem, "%s: couldn't open \"%s\" for reading: %s",
                me, udbaseFilename, strerror(errno));
        return 1;
    }

    char buf[IMP_NAME_MAXLEN + 16]; //16 for requested/toanswer + dash + newline

    pthread_mutex_lock(&db_lock);
    database = newDB();

    if (fgets(buf, IMP_NAME_MAXLEN + 15, file) != NULL) { //throw away first line
        //TODO: error here
    }
    while (fgets(buf, IMP_NAME_MAXLEN + 15, file) != NULL) {
        if (buf[0] != '-' && buf[0] != '.') {
            char username[IMP_NAME_MAXLEN + 1];
            char scanfstr[16];
            sprintf(scanfstr, " %%%ds ", IMP_NAME_MAXLEN);
            int tokens = sscanf(buf, scanfstr, username);
            if (tokens > 0) {
                addUser(username);
            } else {
                //TODO: error
            }
        }
    }

    rewind(file);

    if (fgets(buf, IMP_NAME_MAXLEN + 15, file) != NULL) { //throw away first line
        //TODO: error here
    }
    dbUser_t *user = NULL;
    while (fgets(buf, IMP_NAME_MAXLEN + 15, file) != NULL) {
        if (buf[0] != '-' && buf[0] != '.') {
            char username[IMP_NAME_MAXLEN + 1];
            char scanfstr[16];
            sprintf(scanfstr, " %%%ds ", IMP_NAME_MAXLEN);
            int tokens = sscanf(buf, scanfstr, username);
            if (tokens > 0) {
                user = lookupUser(username);
            } else {
                //TODO: handle error
            }
        } else if (buf[0] == '-') {
            char friendname[IMP_NAME_MAXLEN + 1];
            char status_str[16];
            char scanfstr[16];
            sprintf(scanfstr, "- %%%ds %%%ds ", IMP_NAME_MAXLEN, 15);
            int tokens = sscanf(buf, scanfstr, friendname, status_str);
            impFriend_t status = IMP_FRIEND_YES;
            if (tokens > 0) {
                if (tokens > 1) {
                    if (strcmp(status_str, "requested") == 0) {
                        status = IMP_FRIEND_REQUESTED;
                    } else if (strcmp(status_str, "toanswer") == 0) {
                        status = IMP_FRIEND_TOANSWER;
                    }
                }
                dbUser_t *friend = lookupUser(friendname);
                if (!friend) {
                    //TODO: handle error
                }
                addFriend(user, friend, status);
            } else {
                //TODO: die in a fire
            }
        }
    }

    pthread_mutex_unlock(&db_lock);
    fclose(file);
    return 0;
}

/* you can pass a NULL iem to this if you aren't interested in saving the
   error messages; impEmAdd will have no effect with a NULL iem */
int udbaseWrite(impEm *iem) {
    static const char me[] = "udbaseWrite";
    FILE *file;

    /* ... make sure that user database is being written at the same
       that a client thread is modifying it, either with code here,
       or with limits on how udbaseWrite() is called */
    pthread_mutex_lock(&db_lock);
    file = fopen(udbaseFilename, "w");
    if (!file) {
        impEmAdd(iem, "%s: couldn't open \"%s\" for writing: %s",
                me, udbaseFilename, strerror(errno));
        return 1;
    }

    fprintf(file, "%d users:\n", (int) database->numUsers);
    for (int i = 0; i < database->numUsers; i++) {
        dbUser_t *user = database->users[i];
        fprintf(file, "%s\n", user->name);
        for (int j = 0; j < user->numFriends; j++) {
            dbFriend_t *friend = user->friends[j];
            fprintf(file, "- %s", friend->friend->name);
            if (friend->status == IMP_FRIEND_REQUESTED) {
                fprintf(file, " requested\n");
            } else if (friend->status == IMP_FRIEND_TOANSWER) {
                fprintf(file, " toanswer\n");
            } else {
                fprintf(file, "\n");
            }
        }
        fprintf(file, ".\n");
    }

    fclose(file);
    pthread_mutex_unlock(&db_lock);
    return 0;
}

void *update_thread(void *arg){
    while (true) {
        udbaseWrite(NULL);
        sleep(saveInterval);
    }
    return NULL;
}