#include <stdio.h>
#include <stdlib.h>

#include "abc.h"

void out_note(struct note note) {
	fwrite(&note, sizeof note, 1, stdout);
}

int main()
{
	extern int yylex();
	return yylex();
}
