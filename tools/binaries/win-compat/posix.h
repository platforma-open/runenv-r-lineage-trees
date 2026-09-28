/* Prototypes for posix.c, force-included on Windows: implicitly declared, strsep returns int
 * and its pointer is cut to 32 bits. */
#ifndef IGPHYML_WIN_POSIX_H
#define IGPHYML_WIN_POSIX_H
#include <stdio.h>
#include <sys/types.h>
char *strsep(char **stringp, const char *delim);
ssize_t getline(char **lineptr, size_t *n, FILE *stream);
#endif
