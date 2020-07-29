#ifndef ABC_H
#define ABC_H

struct frac {
	unsigned char n, d;
};

struct note {
	unsigned freq:15;
	unsigned slurred:1;
	unsigned dur_ms:16;
};

struct duplet {
	unsigned char p, q, r;
	/* p notes in time of q for next r notes */
};

/* Key format:
 * sign - sharp (>=0) or flat (<0)
 * absolute value - how many sharp or flat signs.
 * The value should fit 4 bits in 2's complement.
 */
enum {
	KEY_NONE = -8,
	KEY_Cb, KEY_Gb, KEY_Db, KEY_Ab, KEY_Eb, KEY_Bb, KEY_F,
	KEY_C, KEY_G, KEY_D, KEY_A, KEY_E, KEY_B, KEY_Fs, KEY_Cs,
};

#endif /* ABC_H */
