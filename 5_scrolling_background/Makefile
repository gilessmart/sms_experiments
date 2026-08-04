bin/scrolling_background.sms: bin/scrolling_background.o
	wlalink -d -r -v -s linkfile bin/scrolling_background.sms

bin/scrolling_background.o: *.asm data/*.asm
	wla-z80 -o bin/scrolling_background.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
