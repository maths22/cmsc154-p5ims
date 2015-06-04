# cs154-2015 Project 5 ("p5ims") Instant Message Server

CC=gcc
CFLAGS= -Wall -Werror -g -O1
IPATH= -Iimp
LPATH= -Limp

# As you add more source files to your project, list them here
# Source file foo.c should be listed here as "foo.o"
OBJS= main.o defaults.o udbase.o handler.o

all: ims

$(OBJS): ims.h

%.o: %.c
	$(CC) $(CFLAGS) $(IPATH) -c $< -o $@

ims: $(OBJS)
	$(CC) $(CFLAGS) $(IPATH) -o ims $(OBJS) $(LPATH) -Wl,-rpath,imp -lpthread -limp

clean:
	rm -f $(OBJS) ims
