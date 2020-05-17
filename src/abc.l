%{
#include <assert.h>
#include <ctype.h>
#include <limits.h>
#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "abc.h"
#include "output.h"

#define die(fmt, ...) do { fprintf(stderr, fmt"\n", ##__VA_ARGS__); exit(1); } while (0)
#define NO_KEY 0xaa

static struct {
	struct frac M;  // meter
	unsigned K:8;  // key
	unsigned char L;  // unit length = 1/L
	unsigned short Q;  // tempo (1/4 = 60/Q s)

	unsigned slurred;
	struct duplet duplet;

	int dot;
	bool tie;

	int pos, rep_begin, rep_end;
} ctx = {
	.M = {4, 4},
	.K = NO_KEY,
	.L = 4,
	.Q = 120,
};

static struct note parse_note(const char *s);
static struct duplet parse_duplets(const char *s);
static unsigned char parse_key(const char *s);

%}

d	[0-9]
int	{d}+
alpha	[A-Za-z]
ws	[ \t\r\v\f]
scale   {int}?([/]({int})?)*
note	[\^=_]?[A-Ga-g]([']*|[,]*){scale}
rest    [zZ]{scale}

%s HEADER BODY_F INLINE_F BODY

%%

<INITIAL>{

X:{ws}*{int}{ws}*\n	fputs(yytext, stderr); BEGIN(HEADER);

\n	/* skip */

<<EOF>>	|
.+	die("X: line not found; got: %s", yytext);

}

<HEADER>\n	if (ctx.K != NO_KEY) BEGIN(BODY);
<BODY_F>\n	BEGIN(BODY);
<INLINE_F>"]"	BEGIN(BODY);

<HEADER,BODY_F,INLINE_F>{

M:{ws}*C{ws}*/[]\n]	{
	ctx.M.n = ctx.M.d = 4;
}
M:{ws}*C"|"{ws}*/[]\n]	{
	ctx.M.n = 4;
	ctx.M.d = 2;
}
M:{ws}*{int}"/"{int}{ws}*/[]\n] {
	const char *p = strchr(yytext, '/');
	assert(p && *p != '\0');
	ctx.M.n = atoi(yytext + 2);
	ctx.M.d = atoi(p + 1);
}

L:{ws}*1{ws}*/[]\n]	ctx.L = 1;
L:{ws}*"1/"{int}{ws}*/[]\n]	{
	const char *p = strchr(yytext, '/');
	assert(p && *p != '\0');
	ctx.L = atoi(p + 1);
}

K:{ws}*[A-G][#b]?(maj(or)?|m(in(or)?)?)?{ws}*/[]\n]	{
	ctx.K = parse_key(yytext + 2);
}

Q:{ws}*{int}{ws}*/[]\n]	{
	ctx.Q = atoi(yytext + 2);
	if (ctx.Q == 0)
		die("bad Q: %d", ctx.Q);
}
Q:{ws}*"1/"{int}={int}{ws}*/[]\n]	{
	int x, y;
	const char *p = strchr(yytext, '/');
	assert(p && *p != '\0');
	sscanf(p+1, "%d=%d", &x, &y);
	ctx.Q = round(y / (x / 4.0));
	if (x == 0 || y == 0)
		die("bad %s", yytext);
}


[ABCDFGHImNOPRrSsTUVXZ]:[^\]\n]*/[]\n]	fprintf(stderr, "%s\n", yytext);

[^\]\n]*	die("bad header line: %s", yytext);
<<EOF>>		die("incomplete header section");

}

<BODY>{

{rest}		|
{note}		{
	struct note note = parse_note(yytext);
	//fprintf(stderr, "%s => %uHz %ums\n", yytext, note.freq, note.dur_ms);
	if (ctx.tie) {
		ctx.pos += tie_note(note);
		ctx.tie = false;
	} else if (ctx.dot) {
		dot_note(note, ctx.dot);
		++ctx.pos;
	} else {
		put_note(note);
		++ctx.pos;
	}
	ctx.dot = 0;
}

"-"	ctx.tie = true;
">"+		|
"<"+		{
	if (ctx.dot)
		fprintf(stderr, "warning: overriding dot\n");
	ctx.dot = (*yytext == '<') ? -yyleng : yyleng;
}

"("{d}(:({d})?(:{d})?)?	{
	ctx.duplet = parse_duplets(yytext + 1);
}

"("	ctx.slurred++;
")"	if (ctx.slurred) ctx.slurred--;

"|:"	ctx.rep_begin = ctx.pos;
":|]"		|
":|"{int}	|
":|"		{
	if (ctx.rep_end <= ctx.rep_begin)
		ctx.rep_end = ctx.pos;
	repeat(ctx.pos - ctx.rep_begin, ctx.pos - ctx.rep_end);
}
":|:"	{
	if (ctx.rep_end <= ctx.rep_begin)
		ctx.rep_end = ctx.pos;
	repeat(ctx.pos - ctx.rep_begin, ctx.pos - ctx.rep_end);
	ctx.rep_begin = ctx.pos;
}
[[|]{int}	{
	if (ctx.rep_end <= ctx.rep_begin)
		ctx.rep_end = ctx.pos;
}

"{"[^}\n]*"}"	{
	fprintf(stderr, "warning: grace notes dropped\n");
}

![^!\n]*!	|
[.~HLMOPSTuv]	{
	fprintf(stderr, "warning: decoration dropped\n");
}

\"[^"\n]*\"	|
"||"		|
"|]"		|
"|"		|
\\\n		|
\n		|
{ws}+		/* skip */

\n\n		|
<<EOF>>		{
	flush();
	return 0;
}

^[wW]:.*\n	fputs(yytext, stderr);
^[IKLMmNPQRrsTUV]:	{
	yyless(0);
	BEGIN(BODY_F);
}
"["[IKLMmNPQRrUV]:	{
	yyless(1);
	BEGIN(INLINE_F);
}

}

<*>^"%".*\n	/* skip comment */
<*>.		die("bad character: '%c'", *yytext);

%%

int yywrap() { return 1; }

static int letter_to_pitch(char letter, unsigned char key)
{
	static const char letters[] = "CDEFGAB";
	/* p = A4 + 12 * log2(f/440); A4 = 69 (MIDI standard) */
	static const unsigned char values[] = {
		60, 62, 64, 65, 67, 69, 71,
	};
	const char *p = strchr(letters, toupper(letter));
	int idx, pitch;
	assert(p != NULL && *p != '\0');
	idx = p - letters;
	pitch = values[idx];
	if (key & (1 << idx))
		pitch += (key & 0x80) ? -1 : 1;
	return pitch;
}

struct note parse_note(const char *s)
{
	struct note note;
	struct frac dur;
	int accidental = INT_MIN;
	char letter;
	char *endptr;

	if (*s == '^')
		accidental = 1;
	else if (*s == '=')
		accidental = 0;
	else if (*s == '_')
		accidental = -1;
	if (accidental != INT_MIN)
		s++;

	letter = *s++;
	if (letter == 'z' || letter == 'Z') {
		note.freq = 0;
	} else {
		int pitch = 0;
		unsigned char key = 0;

		if (accidental != INT_MIN)
			pitch += accidental; 
		else
			key = ctx.K;
		pitch += letter_to_pitch(toupper(letter), key);

		/* octave modifier */
		if (islower(letter))
			pitch += 12;
		for (; *s == '\''; ++s)
			pitch += 12;
		for (; *s == ','; ++s)
			pitch -= 12;

		note.freq = round(440 * pow(2, (pitch - 69) / 12.0));
	}

	if (letter == 'Z') {
		dur = ctx.M;
	} else {
		dur.n = 1;
		dur.d = ctx.L;
	}
	if (*s) {
		int n = strtol(s, &endptr, 10);
		if (endptr != s) {
			s = endptr;
			n *= dur.n;
			if (n > UCHAR_MAX)
				fprintf(stderr, "duration overflow: %d\n", n);
			else
				dur.n = n;
		}
		while (*s == '/') {
			s++;
			n = strtol(s, &endptr, 10);
			if (endptr == s)
				n = 2;
			s = endptr;
			n *= dur.d;
			if (n > UCHAR_MAX)
				fprintf(stderr, "duration overflow: %d\n", n);
			else
				dur.d = n;
		}
	}
	note.slurred = !!ctx.slurred;

	note.dur_ms = (240000. / ctx.Q) * dur.n / dur.d;
	if (ctx.duplet.r > 0) {
		note.dur_ms *= (double) ctx.duplet.q / ctx.duplet.p;
		--ctx.duplet.r;
	}

	if (*s != '\0')
		fprintf(stderr, "DEBUG: *s == %c\n", *s);
	assert(*s == '\0');
	return note;
}

struct duplet parse_duplets(const char *s)
{
	struct duplet d;

	assert(isdigit(*s));
	d.p = d.r = *s++ - '0';
	d.q = 0;
	if (*s == ':') {
		if (isdigit(*++s))
			d.q = *s++ - '0';
		if (*s == ':' && isdigit(*++s))
			d.r = *s++ - '0';
	}
	assert(*s == '\0');

	if (d.q == 0) {
		switch (d.p) {
		case 2: case 4: case 8:
			d.q = 3;
			break;
		case 3: case 6:
			d.q = 2;
			break;
		case 5: case 7: case 9:
			d.q = (ctx.M.n == 6 || ctx.M.n == 9 || ctx.M.n == 12) ? 3 : 2;
			fprintf(stderr, "warning: default q=%u for M=%u/%u\n",
				d.q, ctx.M.n, ctx.M.d);
			break;
		default:
			die("bad n-lets: %u", d.q);
			break;
		}
	}
	return d;
}

unsigned char parse_key(const char *s) {
	static const unsigned char keys[] = {
		KEY_C, KEY_Db, KEY_D, KEY_Eb, KEY_E, KEY_F,
		KEY_Gb, KEY_G, KEY_Ab, KEY_A, KEY_Bb, KEY_B,
	};
	int accidental = 0;
	int pitch;

	while (isspace(*s))
		s++;
	pitch = letter_to_pitch(*s++, 0);
	if (*s == '#')
		accidental = 1;
	else if (*s == 'b')
		accidental = -1;
	if (accidental) {
		pitch += accidental;
		s++;
	}
	if (*s == 'm' && (s[1] == 'i' || s[1] == '\0'))
		pitch += 3;  // minor -> relative major
	return keys[pitch % 12];
}
