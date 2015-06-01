/*
** cs154-2015 Project 5 IM server; demo text client
** Compile with:
gcc -Wall -Werror -O1 -g -o txtimc txtimc.c -Iimp -Limp -Wl,-rpath,imp -lpthread -limp -lreadline
*/

#include <stdio.h>
#include "stdint.h"
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h> /* inet_ntop */
#include <sys/types.h> /* getaddrinfo */
#include <sys/socket.h>  /* recv, send, getaddrinfo */
#include <netdb.h> /* getaddrinfo */
#include <unistd.h> /* sleep */
#include <pthread.h>
#include <errno.h>
#include <assert.h>
#include <readline/readline.h>
#include <readline/history.h>

#include "imp.h"

#define WHITESPACE " \t\n\r\v\f"       /* K+R pg. 157 */
#define BUFF_SIZE 2048
#define NOT_LOGGED_IN "not logged in"

/* begin globals */
int quiet=0;
int connfd=-1;
char myself[IMP_NAME_MAXLEN+1]=NOT_LOGGED_IN;
/* end globals */

/*
** stringShow: sprints into given buffer "buff" (assumed to be big enough!)
** something like: "1 1 harold" (OP REGISTER harold)
** where "1 1 harold" is the given protocol string "protstr" (though
** \0-terminated at 1st \n) and "OP REGISTER harold" is the human-readable
** display form of it.  If the given protocol string is malformed, then
** an error message describing how its malformed is included.
**
** For project 5, this function is just a convenient thing to have around
** (feel free to copy/modify it for your server code), and because it
** demonstrates functions calls in the imp library.
*/
char *
stringShow(char *buff, const char *protstr) {
  char *pstr=NULL;
  char *disp=NULL;
  char *errs=NULL;
  impEm *iem;
  impMsg *msg;
  int ii;

  /* create imp error message accumulator */
  iem = impEmNew();
  /* parse the given string */
  msg = impStrToMsg(iem, protstr);
  if (!msg) {
    /* protstr was not a valid protocol string */
    /* learn why/how string was malformed */
    errs = impEmSprint(iem);
    /* turn '\n' into ';' in error string so it prints in one line */
    for (ii=0; errs[ii]; ii++) {
      if ('\n' == errs[ii]) {
        errs[ii] = ';';
      }
    }
  } else {
    /* protstr was a valid protocol string */
    disp = impMsgToDisplay(NULL, msg);
    impMsgFree(msg);
    /* lose the '\n' in display string */
    for (ii=0; disp[ii]; ii++) {
      if ('\n' == disp[ii]) {
        disp[ii] = '\0';
        break;
      }
    }
  }
  /* free the imp error message accumulator */
  impEmFree(iem);
  /* now either errs or disp is non-NULL */
  /* make copy of protstr, \0-terminating at first \n (for sake of printing) */
  pstr = strdup(protstr);
  for (ii=0; pstr[ii]; ii++) {
    if ('\n' == pstr[ii]) {
      pstr[ii] = '\0';
      break;
    }
  }
  if (disp) {
    sprintf(buff, "\"%s\" (%s)", pstr, disp);
  } else {
    sprintf(buff, "\"%s\" (bad: %s)", pstr, errs);
  }
  free(pstr);
  if (disp) free(disp);
  if (errs) free(errs);
  return buff;
}

int
serverConnect(char *hostname, unsigned short port) {
  static const char me[]="serverConnect";
  char where[BUFF_SIZE], portStr[128];
  int status, socketfd=-1;
  struct addrinfo hints, *servinfo, *svi;

  sprintf(portStr, "%u", port);
  bzero(&hints, sizeof(hints));
  hints.ai_family = AF_INET;
  hints.ai_socktype = SOCK_STREAM;
  status = getaddrinfo(hostname, portStr, &hints, &servinfo);
  if (status) {
    fprintf(stderr, "%s: getaddrinfo() error: %s\n", me, gai_strerror(status));
    return -1;
  }

  for (svi = servinfo; svi != NULL; svi = svi->ai_next) {
    socketfd = socket(svi->ai_family, svi->ai_socktype, svi->ai_protocol);
    if (socketfd < 0) {
      sprintf(where, "%s: socket() error", me);
      perror(where);
      break;
    }
    status = connect(socketfd, svi->ai_addr, svi->ai_addrlen);
    if (status != 0) {
      sprintf(where, "%s: connect() error", me);
      perror(where);
      socketfd = -1;
      break;
    }
    printf("Connected to %s:%hu\n", hostname, port);
    break;
  }
  if (svi == NULL) {
    fprintf(stderr, "%s: nothing to connect to\n", me);
    return -1;
  }

  freeaddrinfo(servinfo);
  return socketfd;
}

int
processServerStr(char *allstr) {
  static const char me[]="processServerStr";
  unsigned int ii, start;
  size_t alllen;
  impEm *iem;
  unsigned int respIdx=0;
  char buff[BUFF_SIZE];

  iem = impEmNew();
  /* we loop through what may be multiple \n-terminated protocol
     strings all packed into allstr.  impStrToMsg can process
     only one protocol string at a time */
  start = 0;
  alllen = strlen(allstr);
  do {
    char *pstr = allstr + start;
    /* turn this \n-terminated message into \0-terminated string */
    for (ii=start; ii<alllen; ii++) {
      if (allstr[ii] == '\n') {
	allstr[ii] = '\0';
        start = ii+1;
	break;
      }
    }
    if (!quiet) {
      printf("%sserver response %u: %s\n", !respIdx ? "\n" : "",
             respIdx, stringShow(buff, pstr));
    }
    /* parse server response */
    impMsg *pm = impStrToMsg(iem, pstr);
    if (!pm) {
      fprintf(stderr, "%s: problem parsing response %u \"%s\":\n",
              me, respIdx, pstr);
      impEmFprint(stderr, iem);
      impEmFree(iem);
      return 1;
    }

    /* now we handle the protocol message. */
    if (IMP_MSG_TYPE_ACK == pm->mt) {
      impMsgAck *mack = (impMsgAck*)pm;

      if (IMP_OP_LOGIN == mack->op) {
	strcpy(myself, mack->userName);
      } else if (IMP_OP_LOGOUT == mack->op) {
	strcpy(myself, NOT_LOGGED_IN);
      }
    } else if (IMP_MSG_TYPE_OP == pm->mt) {
      impMsgOp *mop = (impMsgOp*)pm;
      if (IMP_OP_IM == mop->op) {
        printf("\n *** %s says \"%s\" ***\n", mop->userName, mop->IM);
      }
    } else if (IMP_MSG_TYPE_STATUS == pm->mt) {
      impMsgStatus *mstat = (impMsgStatus*)pm;
      if (IMP_FRIEND_YES == mstat->status) {
        printf("\n *** friend %s: %s ***\n", mstat->userName,
               impActiveStr(mstat->active));
      } else {
        printf("\n *** %s: %s ***\n", mstat->userName,
               impFriendStr(mstat->status));
      }
    } else if (IMP_MSG_TYPE_ERROR == pm->mt) {
      char *disp;
      disp = impMsgToDisplay(NULL, pm);
      disp[strlen(disp)-1]='\0';
      printf("\n !!! %s !!!\n", disp);
    }

    impMsgFree(pm);
    respIdx++;
  } while (start < alllen);

  return 0;
}

void *
getServerStr(void *args /* unused */) {
  static const char me[]="getServerStr";
  char str[BUFF_SIZE];
  char where[BUFF_SIZE];
  ssize_t readBytes;
  int pss;

  while (1) {
    bzero(str, BUFF_SIZE); /* this effectively \0-terminates whatever ends
                              up in str */
    readBytes = recv(connfd, str, BUFF_SIZE, 0);
    if (readBytes < 0) {
      sprintf(where, "%s: recv() failed (readBytes=%d)", me, (int)readBytes);
      perror(where);
      break;
    }
    if (!readBytes) {
      fprintf(stderr, "%s: server closed connection\n", me);
      if (close(connfd)) {
        sprintf(where, "%s: close() after server disconnect", me);
        perror(where);
      }
      connfd = -1;
      break;
    }
    if ((pss=processServerStr(str))) {
      fprintf(stderr, "%s: problem with server message (ret=%d)\n", me, pss);
      break;
    }
  }
  return NULL;
}

void
processOp(impOp_t op, char *_args) {
  static const char me[]="processOp";
  char *name=NULL, *IM=NULL;
  char *args, buff[BUFF_SIZE];
  char *str=NULL;
  impEm *iem;

  /* use impMsgUserArg() to first determine how many arguments
     to extract from given _args */
  args = _args;
  if (!impMsgUserArg(IMP_MSG_TYPE_OP, op)) {
    /* no need for username (nor IM) arg */
    if (args && strlen(args)) {
      fprintf(stderr, "%s: WARNING: IGNORING extraneous \"%s\"\n", me, args);
    }
  } else {
    /* do need username */
    if (!args || !strlen(args)) {
      fprintf(stderr, "%s: didn't get username for OP %s\n",
              me, impOpStr(op));
      return;
    }    
    name = strdup(args);
    if (1 != sscanf(args, "%s", name)) {
      fprintf(stderr, "%s: didn't get username for OP %s\n",
              me, impOpStr(op));
      free(name);
      return;
    }
    args += strspn(args, WHITESPACE);
    args += strlen(name);
    if (IMP_OP_IM == op) {
      IM = strdup(args);
      /* and also need message text */
      if (!strlen(args) || !strlen(args+1)
          || 1 != sscanf(args+1, "%[^\n]", IM)) {
        fprintf(stderr, "%s: didn't get message text for OP %s\n",
                me, impOpStr(op));
        free(name); free(IM);
        return;
      }
    } else if (strlen(args)) {
      fprintf(stderr, "%s: WARNING: IGNORING extraneous \"%s\"\n", me, args);
    }
  }

  iem = impEmNew();
  /* use impMsgUserArg() to help determine how many arguments to pass
     to impStrNew() (the same applies to impMsgNew or impDisplayNew) */
  if (!impMsgUserArg(IMP_MSG_TYPE_OP, op)) {
    /* no need for user (nor IM) arg */
    str = impStrNew(iem, IMP_MSG_TYPE_OP, op, IMP_END);
  } else {
    if (op != IMP_OP_IM) {
      /* need user but not IM */
      str = impStrNew(iem, IMP_MSG_TYPE_OP, op, name, IMP_END);
    } else {
      /* do need the IM as well, for IMP_OP_IM */
      str = impStrNew(iem, IMP_MSG_TYPE_OP, op, name, IM, IMP_END);
    }
  }
  if (!str) {
    fprintf(stderr, "%s: impStrNew trouble:\n", me);
    impEmFprint(stderr, iem);
  }
  impEmFree(iem);

  if (!quiet) {
    printf("sending to server: %s\n", stringShow(buff, str));
  }
  send(connfd, str, strlen(str), 0);
  free(str);
  free(name);
  free(IM);
  return;
}

void *
getTextInput(void *data) {
  static const char me[]="getTextInput";
  char *buff=NULL, _buff[BUFF_SIZE+1], *cmd, *args,
    prompt[BUFF_SIZE+1];

  rl_bind_key ('\t', rl_insert);
  printf("Type \"help\" for list of supported commands\n");
  while (1) {
    if (-1 == connfd) {
      fprintf(stderr, "%s: server connection closed; we are done\n", me);
      return NULL;
    }
    sprintf(prompt, "imc(%s)> ", myself);
    buff = readline(prompt);
    if (!buff) {
      fprintf(stderr, "\nGot EOF; quitting\n");
      exit(0);
    }
    if (strlen(buff)) {
      add_history(buff);
    }
    /* immediately copy buff to _buff on stack, and then free buff, so
       there's no memory leak even when the other thread exit()s on us */
    if (strlen(buff) < BUFF_SIZE) {
      strcpy(_buff, buff);
    } else {
      memcpy(_buff, buff, BUFF_SIZE);
      _buff[BUFF_SIZE] = '\0';
    }
    if (buff) free(buff);
    cmd = _buff;
    cmd += strspn(cmd, WHITESPACE);
    if (!strlen(cmd)) {
      continue;
    }
    args = strchr(cmd, ' ');
    if (args) {
      *args = '\0'; /* \0-terminates cmd */
      args += 1;
    }

    if (!strcmp(cmd, "register") || !strcmp(cmd, "reg")) {
      processOp(IMP_OP_REGISTER, args);
    } else if (!strcmp(cmd, "login")) {
      processOp(IMP_OP_LOGIN, args);
    } else if (!strcmp(cmd, "logout")) {
      processOp(IMP_OP_LOGOUT, args);
    } else if (!strcmp(cmd, "friend_request")
               || !strcmp(cmd, "req")) {
      processOp(IMP_OP_FRIEND_REQUEST, args);
    } else if (!strcmp(cmd, "friend_remove")
               || !strcmp(cmd, "rm")) {
      processOp(IMP_OP_FRIEND_REMOVE, args);
    } else if (!strcmp(cmd, "friend_list")
               || !strcmp(cmd, "list")) {
      processOp(IMP_OP_FRIEND_LIST, args);
    } else if (!strcmp(cmd, "im")) {
      processOp(IMP_OP_IM, args);
    } else if (!strcmp(cmd, "raw")) {
      if (connfd > 0 && args) {
        char *rawnl = (char*)calloc(2+strlen(args), sizeof(char));
        assert(rawnl);
        sprintf(rawnl, "%s\n", args);
        /* turn tabs into newlines, so that we can test server's
           ability to respond to multiple protocol messages at once */
        size_t ll=strlen(args), ii;
        for (ii=0; ii<ll; ii++) {
          if ('\t' == rawnl[ii]) {
            rawnl[ii] = '\n';
          }
        }
        if (0 > send(connfd, rawnl, strlen(rawnl), 0)) {
          fprintf(stderr, "\n%s ERROR: send() to server failed: %s\n",
                  myself, strerror(errno));
        }
        free(rawnl);
      }
    } else if (!strcmp(cmd, "sleep")) {
      int secs;
      if (1 != sscanf(args, "%d", &secs)) {
        fprintf(stderr, "%s: couldn't parse \"%s\" as integer\n", me, args);
      } else {
        printf("sleep(%d) ... \n", secs);
        sleep(secs);
      }
    } else if (!strcmp(cmd, "quit")
               || !strcmp(cmd, "q")) {
      printf("quitting\n");
      /* have to exit, rather than return; so that the whole
         process (and the other thread) come down too */
      exit(0);
    } else if (!strcmp(cmd, "help")
               || !strcmp(cmd, "?")
               || !strcmp(cmd, "h")) {
      printf("Commands supported:\n");
      printf("\t \"register <user>\" or \"reg <user>\"\n");
      printf("\t \"login <user>\"\n");
      printf("\t \"logout\"\n");
      printf("\t \"friend_request <user>\" or \"req <user>\"\n");
      printf("\t \"friend_remove <user>\" or \"rm <user>\"\n");
      printf("\t \"friend_list\" or \"list\"\n");
      printf("\t \"im <user> <msg>\"\n");
      printf("\t \"raw <string>\": send bare string to server\n");
      printf("\t \"sleep <t>\"\n");
      printf("\t \"quit\" or \"q\"\n");
    } else {
      fprintf(stderr, "couldn't parse command \"%s%s%s\"\n", cmd,
              args ? " " : "", args ? args : "");
    }
  }
  return NULL;
}

int
textInit() {
  pthread_t input, server;
  void *rv;

  pthread_create(&input, NULL, getTextInput, NULL);
  pthread_create(&server, NULL, getServerStr, NULL);

  /* threads run for as long as they need */

  pthread_join(input, &rv);
  pthread_join(server, &rv);
  return 0;
}

void
usage(const char *me) {
  fprintf(stderr, "usage: %s [-q] -s server -p port#\n", me);
  fprintf(stderr, "  The -q quiet option turns off some possibly useful\n");
  fprintf(stderr, "  display of the protocol strings (and what they mean)\n");
  fprintf(stderr, "  being sent to or received from the server\n");
  exit(1);
}

int
main(int argc, char *argv[]) {
  char *me, *server=NULL;
  int opt; /* current option being parsed */
  unsigned short port=0;

  me = argv[0];
  while ((opt = getopt(argc, argv, "qs:p:")) != -1)
    switch (opt) {
    case 'q':
      quiet = 1;
      break;
    case 's':
      server = optarg;
      break;
    case 'p':
      if (1 != sscanf(optarg, "%hu", &port)) {
        fprintf(stderr, "%s: couldn't parse \"%s\" as port for -p\n",
                me, optarg);
        break;
      }
      break;
    default:
      usage(me);
  }
  if (!( server && port )) {
    usage(me);
  }

  /* gets the socket for the connection with the server */
  connfd = serverConnect(server, port);
  if (-1 == connfd) {
    fprintf(stderr, "%s: Couldn't connect to server %s:%u\n",
            me, server, port);
    exit(1);
  }

  textInit();

  exit(0);
}
