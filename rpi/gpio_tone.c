#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <signal.h>
#include <wiringpi/wiringPi.h>
#include <wiringpi/softTone.h>

#ifndef OUT_PIN
#define OUT_PIN 26
#endif

#define SEP_MS 12

int interrupted = 0;

struct note {
	unsigned freq:15;
	unsigned slurred:1;
	unsigned dur:16;
};

void toneOnPin(int pin) {
	bool slurred = false;

	pinMode(pin, OUTPUT);
	softToneCreate(pin);
	while (!interrupted) {
		struct note note;
		unsigned dur;

		if (fread(&note, sizeof note, 1, stdin) != 1)
			break;
		dur = note.dur;
		if (!(slurred && note.slurred)) {
			softToneWrite(pin, 0);
			delay(SEP_MS);
			dur = (dur >= SEP_MS) ? dur - SEP_MS : 0;
		}
		slurred = note.slurred;
		softToneWrite(pin, note.freq);
		delay(dur);
	}
	pinMode(pin, INPUT);
}

void sighandler(int signal) {
	if (signal == SIGINT)
		interrupted = 1;
}

int main()
{
	if (piHiPri(99) != 0)
		perror("piHiPri");
	wiringPiSetup();
	signal(SIGINT, sighandler);
	toneOnPin(OUT_PIN);
	return interrupted;
}
