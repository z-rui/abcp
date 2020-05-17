#ifndef OUTPUT_H
#define OUTPUT_H

#include "abc.h"

void flush(void);
void put_note(struct note);
void dot_note(struct note, int);
int tie_note(struct note);
void repeat(unsigned, unsigned);

#endif /* OUTPUT_H */
