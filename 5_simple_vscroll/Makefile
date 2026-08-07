bin/simple_vscroll.sms: bin/simple_vscroll.o
	wlalink -d -r -v -s linkfile bin/simple_vscroll.sms

bin/simple_vscroll.o: *.asm data/*.asm
	wla-z80 -o bin/simple_vscroll.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
