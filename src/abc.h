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

/* format:
 * 7 6543210
 * b BAGFEDC
 */
enum {
	KEY_C = 0x0,   // #:
	KEY_G = 0x08,  // #: F
	KEY_D = 0x09,  // #: CF
	KEY_A = 0x19,  // #: CFG
	KEY_E = 0x1b,  // #: CDFG
	KEY_B = 0x3b,  // #: CDFGA
	KEY_Gb = 0xf7, // b: CDEGAB
	KEY_Db = 0xf6, // b: DEGAB
	KEY_Ab = 0xe6, // b: DEAB
	KEY_Eb = 0xe4, // b: EAB
	KEY_Bb = 0xc4, // b: EB
	KEY_F = 0xc0,  // b: B
};

#endif /* ABC_H */
