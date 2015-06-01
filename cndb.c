/*
** for making a canonical version of p5ims database file;
** the users sorted, and lines within user sorted.
** Can also be used to compare two database files.
** Compile with:
gcc -Wall -Werror -g -O1 -o cndb cndb.c
**
** by Gordon Kindlmann for cs154-2015
*/

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

const char *me;

typedef struct {
  char *name;
  char **fline;
  unsigned int fnum;
} dbUser_t;

typedef struct {
  dbUser_t *user;
  unsigned int unum;
} db_t;

void dbUserInit(dbUser_t *uu, unsigned int maxFriendNum) {
  uu->name = NULL;
  uu->fline = (char **)malloc(maxFriendNum*sizeof(char*));
  assert(uu->fline);
  uu->fnum = 0;
  return;
}

void dbUserDone(dbUser_t *uu) {
  unsigned int fi;
  free(uu->name);
  for (fi=0; fi<uu->fnum; fi++) {
    free(uu->fline[fi]);
  }
  free(uu->fline);
  return;
}

FILE *fopener(const char *fname) {
  FILE *ret;
  if (!strcmp("-", fname)) {
    ret = stdin;
  } else {
    ret = fopen(fname, "r");
    if (!ret) {
      fprintf(stderr, "%s: couldn't open \"%s\" for reading: %s\n",
	      me, fname, strerror(errno));
    }
  }
  return ret;
}

void fcloser(FILE *ff) {
  if (ff && stdin != ff) {
    fclose(ff);
  }
  return;
}

int getliner(char **pline, size_t *psize, FILE *file,
             ssize_t wantlen) {
  ssize_t red;

  red = getline(pline, psize, file);
  if (red <= -1) {
    fprintf(stderr, "%s: hit EOF\n", me);
    return 1;
  }
  if (red <= 1) {
    fprintf(stderr, "%s: got empty line\n", me);
    return 1;
  }
  if ('\n' != (*pline)[red-1]) {
    fprintf(stderr, "%s: line didn't end with '\\n'\n", me);
    return 1;
  }
  (*pline)[red-1] = '\0';
  if (!( red-1 >= wantlen )) {
    fprintf(stderr, "%s: got line \"%s\" with %u chars before \\n, "
            "but wanted >= %u\n", me, *pline, (unsigned int)(red-1),
            (unsigned int)wantlen);
    return 1;
  }
  return 0;
}

int userCompare(const void *_aa, const void *_bb) {
  dbUser_t *aa = (dbUser_t *)_aa;
  dbUser_t *bb = (dbUser_t *)_bb;
  return strcmp(aa->name, bb->name);
}

int lineCompare(const void *_aa, const void *_bb) {
  char *aa = *((char **)_aa);
  char *bb = *((char **)_bb);
  return strcmp(aa, bb);
}

db_t *dbRead(FILE *ff) {
  db_t *db;
  char *line, tbuf[128];
  size_t lsize;

  lsize = 0;
  line = NULL;
  if (getliner(&line, &lsize, ff, 8)) {
    fprintf(stderr, "%s: couldn't read first line\n", me);
    return NULL;
  }
  assert(line);
  unsigned int nuser;
  if (1 != sscanf(line, "%u users:", &nuser)) {
    fprintf(stderr, "%s: couldn't parse \"N users\" from first "
            "line \"%s\"\n", me, line);
    return NULL;
  }
  sprintf(tbuf, "%u users:", nuser);
  if (strcmp(tbuf, line)) {
    fprintf(stderr, "%s: first line \"%s\" more than \"%s\"\n",
            me, line, tbuf);
    return NULL;
  }
  db = (db_t *)malloc(sizeof(db_t));
  assert(db);
  db->unum = nuser;
  db->user = (dbUser_t *)malloc(nuser*sizeof(dbUser_t));
  if (!db->user) {
    fprintf(stderr, "%s: failed to allocate %u users\n", me, nuser);
    return NULL;
  }
  unsigned int ui, li;
  for (ui=0; ui<nuser; ui++) {
    if (getliner(&line, &lsize, ff, 1)) {
      fprintf(stderr, "%s: couldn't read username %u/%u\n", me, ui, nuser);
      return NULL;
    }
    dbUserInit(db->user + ui, nuser);
    db->user[ui].name = strdup(line);
    li = 0;
    do {
      if (getliner(&line, &lsize, ff, 1)) {
        fprintf(stderr, "%s: couldn't read friend line %u of user %u (%s)\n",
                me, li, ui, db->user[ui].name);
        return NULL;
      }
      if (strcmp(".", line)) {
        if (!(strlen(line) >= 3 && '-' == line[0] && ' ' == line[1])) {
          fprintf(stderr, "%s: user %u (%s) friend line %u \"%s\" should "
                  "start with \"- \" with strlen >= 3 (not %u)\n",
                  me, ui, db->user[ui].name, li, line,
                  (unsigned int)strlen(line));
          return NULL;
        }
        db->user[ui].fline[li] = strdup(line);
      }
      li++;
    } while (strcmp(".", line));
    db->user[ui].fnum = li-1;
    qsort(db->user[ui].fline, li-1, sizeof(char*), lineCompare);
  }
  qsort(db->user, nuser, sizeof(dbUser_t), userCompare);
  free(line);
  return db;
}

void dbFree(db_t *db) {
  unsigned int ui;
  for (ui=0; ui<db->unum; ui++) {
    dbUserDone(db->user + ui);
  }
  free(db->user);
  free(db);
}

void usage(void) {
  /*                      0     1       (2)   2   (3) */
  fprintf(stderr, "usage: %s <dbIn> [<dbToCompareTo>]\n", me);
  fprintf(stderr, "\n");
  fprintf(stderr, "When given a single argument, a canonical representation\n");
  fprintf(stderr, "of the database is printed to stdout.  When given two\n");
  fprintf(stderr, "arguments, the two databases are compared, and any\n");
  fprintf(stderr, "differences are reported to stdout (like with \"diff\")\n");
  return;
}

int
main(int argc, const char **argv) {
  FILE *fin, *fincomp;

  me = argv[0];
  if (!(2 == argc || 3 == argc)) {
    usage();
    return 1;
  }
  if (!(fin = fopener(argv[1]))) {
    usage();
    return 1;
  }
  if (3 == argc) {
    if (!(fincomp = fopener(argv[2]))) {
      usage();
      return 1;
    }
  } else {
    fincomp = NULL;
  }

  db_t *db, *dbcomp;
  if (!(db = dbRead(fin))) {
    fprintf(stderr, "%s: error reading database from \"%s\"\n", me, argv[1]);
    return 1;
  }
  fcloser(fin);
  if (fincomp) {
    if (!(dbcomp = dbRead(fincomp))) {
      fprintf(stderr, "%s: error reading database from \"%s\"\n", me, argv[2]);
      return 1;
    }
    fcloser(fincomp);
  } else {
    dbcomp = NULL;
  }

  unsigned int ui, li;
  if (!dbcomp) {
    printf("%u users:\n", db->unum);
    for (ui=0; ui<db->unum; ui++) {
      printf("%s\n", db->user[ui].name);
      for (li=0; li<db->user[ui].fnum; li++) {
        printf("%s\n", db->user[ui].fline[li]);
      }
      printf(".\n");
    }
  } else {
    if (db->unum != dbcomp->unum) {
      printf("%s: number users %u != %u\n", me, db->unum, dbcomp->unum);
      return 1;
    }
    for (ui=0; ui<db->unum; ui++) {
      const char *aa;
      const char *bb;
      aa = db->user[ui].name;
      bb = dbcomp->user[ui].name;
      if (strcmp(aa, bb)) {
        printf("%s: user %u \"%s\" != \"%s\"\n", me, ui, aa, bb);
        return 1;
      }
      if (db->user[ui].fnum != dbcomp->user[ui].fnum) {
        printf("%s: user %u \"%s\" # friend lines %u != %u\n",
               me, ui, db->user[ui].name,
               db->user[ui].fnum, dbcomp->user[ui].fnum);
        return 1;
      }
      for (li=0; li<db->user[ui].fnum; li++) {
        aa = db->user[ui].fline[li];
        bb = dbcomp->user[ui].fline[li];
        if (strcmp(aa, bb)) {
          printf("%s: user %u \"%s\" friend line %u \"%s\" != \"%s\"\n",
                 me, ui, db->user[ui].name, li, aa, bb);
          return 1;
        }
      }
    }
    dbFree(dbcomp);
  }
  dbFree(db);

  return 0;
}
