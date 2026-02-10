bin/sprite_demo.sms: bin/sprite_demo.o
	wlalink -d -r -v -s linkfile bin/sprite_demo.sms

bin/sprite_demo.o: *.asm data/*.asm
	wla-z80 -o bin/sprite_demo.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
