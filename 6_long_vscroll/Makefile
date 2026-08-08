bin/long_vscroll.sms: bin/long_vscroll.o
	wlalink -d -r -v -s linkfile bin/long_vscroll.sms

bin/long_vscroll.o: *.asm data/*.asm
	wla-z80 -o bin/long_vscroll.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
