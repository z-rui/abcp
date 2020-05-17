CFLAGS=-Wall -O2

all: abc2bin bin2txt

abc2bin: abc2bin.o lex.yy.o output.o
	$(CC) $(LDFLAGS) -o $@ $^ -lm

bin2txt: bin2txt.o
	$(CC) $(LDFLAGS) -o $@ $^

lex.yy.c: abc.l
	lex $<

main.o: main.c abc.h
lex.yy.o: lex.yy.c abc.h
output.o: output.c abc.h
abc2bin.o: abc2bin.c abc.h
bin2txt.o: bin2txt.c abc.h

clean:
	rm -f *.o lex.yy.c

.PHONY: all clean
