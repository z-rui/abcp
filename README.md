# Parse and play ABC

Turn ABC notation

```
X:1
L:1/8
K:C
GEE2 | FDD2 | CDEF | GGG2 |
GEE2 | FDD2 | CEGG | C4 |
```

into a stream of notes

```
392Hz	250ms
330Hz	250ms
330Hz	500ms
349Hz	250ms
294Hz	250ms
294Hz	500ms
262Hz	250ms
...
```

## Usage

To build, run `make` in `src/`.
`lex` is required to generate scanner from `abc.l`

- `abc2bin` turns ABC into binary
- `bin2txt` turn binary into text

Pipe the two programs to convert ABC into text.

## Use on a Raspberry Pi

- `rpi/gpio_tone` reads binary drives a GPIO output.
- Connect the pin to a buzzer to listen to the music. 🎶
