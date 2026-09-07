bin/2dscroll.sms: bin/2dscroll.o
	wlalink -d -r -v -s linkfile bin/2dscroll.sms

bin/2dscroll.o: *.asm data/*.asm
	wla-z80 -o bin/2dscroll.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
