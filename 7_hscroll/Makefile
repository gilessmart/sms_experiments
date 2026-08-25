bin/hscroll.sms: bin/hscroll.o
	wlalink -d -r -v -s linkfile bin/hscroll.sms

bin/hscroll.o: *.asm data/*.asm
	wla-z80 -o bin/hscroll.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
