#ifndef UDBASE_H
#define	UDBASE_H

#include "imp/imp.h"

#include "types.h"
#include "globals.h"

struct _db_t {
  dbUser_t **users;
  size_t numUsers;
  size_t _memsize;
  pthread_rwlock_t lock;
};

struct _dbUser_t {
  char *name;
  impActive_t active;
  dbFriend_t **friends;
  size_t numFriends;
  size_t _memsize;
  connection_t *thread;
};

struct _dbFriend_t {
    dbUser_t *friend;
    impFriend_t status;
};


//Database manipulation
void addUser(char *username);
void addFriend(dbUser_t *user, dbUser_t *friend, impFriend_t status);
void removeFriend(dbUser_t *user, dbUser_t *friend);
dbUser_t *lookupUser(char *username);
dbFriend_t *lookupFriend(dbUser_t *user, dbUser_t *friend);
void setFriendStatus(dbFriend_t *friend, impFriend_t status);
void setUserStatus(dbUser_t *user, impActive_t active, connection_t *thread);


//Database file manipulation
int udbaseRead(impEm *iem);
int udbaseWrite(impEm *iem);

void *update_thread(void *arg);

#endif	/* UDBASE_H */

