#ifndef HANDLER_H
#define	HANDLER_H

/* if "quit" is typed on on stdin, call serverStop() */
void readQuitFromStdin(void);
/* start the server */
int serverStart(impEm *iem);
/* stop the server and clean up dynamically allocated resources */
void serverStop(void);

#endif	/* HANDLER_H */

