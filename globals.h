#ifndef GLOBALS_H
#define	GLOBALS_H

/* how much verbose debugging messages to print during operation
 */
int verbose; 
/* interval, in seconds, with which to save user database
 */
int saveInterval;
/* port to listen on
 */
unsigned short listenPort;
/* filename for user database
 */
const char *udbaseFilename;
/* flag to say (by being non-zero) that its time to shut things down and quit
 * cleanly. This is set by readQuitFromStdin()
 */
int quitting;

db_t *database;
pthread_mutex_t db_lock;

#endif	/* GLOBALS_H */

