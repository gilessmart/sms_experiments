bin/vscroll.sms: bin/vscroll.o
	wlalink -d -r -v -s linkfile bin/vscroll.sms

bin/vscroll.o: *.asm data/*.asm
	wla-z80 -o bin/vscroll.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
