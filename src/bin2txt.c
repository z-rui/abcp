#include <stdio.h>
#include <stdlib.h>

#include "abc.h"

int main()
{
	struct note note;
	while (fread(&note, sizeof note, 1, stdin) == 1)
		printf("%uHz\t%ums%s\n",
			note.freq, note.dur_ms,
			note.slurred ? "\tslurred" : "");
	return 0;
}
