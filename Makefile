# cs154-2015 Project 5 ("p5ims") Instant Message Server

CC=gcc
CFLAGS= -std=gnu99 -Wall -Werror -pedantic -Wextra -g -O1
IPATH= -Iimp
LPATH= -Limp

OBJS= main.o defaults.o udbase.o handler.o connection.o user.o friends.o im.o

all: ims

$(OBJS): ims.h

%.o: %.c
	$(CC) $(CFLAGS) $(IPATH) -c $< -o $@

ims: $(OBJS)
	$(CC) $(CFLAGS) $(IPATH) -o ims $(OBJS) $(LPATH) -Wl,-rpath,'$$ORIGIN/imp' -lpthread -limp

clean:
	rm -f $(OBJS) ims
