/* strsep and getline, which IgPhyML calls and mingw-w64 does not provide. */
#include "posix.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

char *strsep(char **stringp, const char *delim) {
  char *start = *stringp, *p;
  if (!start) return NULL;
  p = start + strcspn(start, delim);
  if (*p) { *p = '\0'; *stringp = p + 1; } else *stringp = NULL;
  return start;
}

ssize_t getline(char **lineptr, size_t *n, FILE *stream) {
  size_t len = 0;
  int c;
  if (!lineptr || !n || !stream) { errno = EINVAL; return -1; }
  if (!*lineptr || *n == 0) {
    *n = 128;
    if (!(*lineptr = malloc(*n))) return -1;
  }
  while ((c = fgetc(stream)) != EOF) {
    if (len + 1 >= *n) {
      size_t m = *n * 2;
      char *q = realloc(*lineptr, m);
      if (!q) return -1;
      *lineptr = q; *n = m;
    }
    (*lineptr)[len++] = (char)c;
    if (c == '\n') break;
  }
  if (len == 0) return -1;
  (*lineptr)[len] = '\0';
  return (ssize_t)len;
}
