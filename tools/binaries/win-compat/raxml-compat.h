/* Force-included into every raxml-ng translation unit on the Windows build. */
#ifndef RAXML_WIN_COMPAT_H
#define RAXML_WIN_COMPAT_H
#ifdef _WIN32
#define _USE_MATH_DEFINES
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
/* mingw-w64 has no asprintf. */
static inline int raxml_win_asprintf(char **out, const char *fmt, ...) {
  va_list ap, aq;
  va_start(ap, fmt);
  va_copy(aq, ap);
  int n = vsnprintf(NULL, 0, fmt, ap);
  va_end(ap);
  if (n < 0 || !(*out = (char *)malloc((size_t)n + 1))) { va_end(aq); return -1; }
  vsnprintf(*out, (size_t)n + 1, fmt, aq);
  va_end(aq);
  return n;
}
#define asprintf raxml_win_asprintf
#include <stdint.h>
typedef uint32_t u_int32_t;
/* realpath(path, NULL) allocates, as _fullpath(NULL, path, 0) does. */
static inline char *raxml_win_realpath(const char *path, char *resolved) {
  return _fullpath(resolved, path, resolved ? _MAX_PATH : 0);
}
#define realpath raxml_win_realpath
#endif
#endif
