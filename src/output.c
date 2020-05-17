/*
 * Generic output layer
 *
 * This layer caches output notes so that it can handle:
 *   - dotted notes
 *   - tied notes
 *   - repetition
 */

#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

#include "output.h"

#define die(fmt, ...) do { fprintf(stderr, fmt"\n", ##__VA_ARGS__); exit(1); } while (0)
#define NOTE_BUFSIZ 65536

/* output to the down level */
extern void out_note(struct note);

static bool dirty;  // last note not flushed?
static unsigned short front = 0, rear = 0;
static struct note buf[NOTE_BUFSIZ];

void flush(void)
{
	if (dirty) {
		out_note(buf[(rear-1) % NOTE_BUFSIZ]);
		dirty = false;
	}
}

void put_note(struct note note)
{
	flush();
	buf[rear] = note;
	rear = (rear+1) % NOTE_BUFSIZ;
	dirty = true;
}

static void do_dot_note(struct note *prev, struct note *next, unsigned amount)
{
	unsigned next_dur_ms;

	if (amount > 3)
		fprintf(stderr, "warning: bad dot amount: %u\n", amount);
	if (prev->dur_ms != next->dur_ms)
		fprintf(stderr, "warning: dotting two notes of different length\n");
	next_dur_ms = next->dur_ms / (1 << amount);
	prev->dur_ms += next->dur_ms - next_dur_ms;
	next->dur_ms = next_dur_ms;
}

void dot_note(struct note note, int amount)
{
	struct note *prev = &buf[(rear-1) % NOTE_BUFSIZ];

	if (amount < 0)
		do_dot_note(&note, prev, -amount);
	else if (amount > 0)
		do_dot_note(prev, &note, amount);
	put_note(note);
}

int tie_note(struct note note)
{
	struct note *prev = &buf[(rear-1) % NOTE_BUFSIZ];

	if (prev->freq != note.freq) {
		fprintf(stderr, "warning: tying two notes of different freq\n");
		/* don't tie them */
		put_note(note);
		return 1;
	}
	prev->dur_ms += note.dur_ms;
	return 0;
}

void repeat(unsigned count, unsigned skip_tail)
{
	unsigned len = (rear - front) % NOTE_BUFSIZ;
	unsigned i;

	if (count > len)
		die("overflow: please increase NOTE_BUFSIZE >= %u", count);

	flush();
	i = (rear - count) % NOTE_BUFSIZ;
	count -= skip_tail;

	while (count--)
		out_note(buf[i++]);
}
