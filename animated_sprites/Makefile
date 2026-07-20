bin/animated_sprites.sms: bin/animated_sprites.o
	wlalink -d -r -v -s linkfile bin/animated_sprites.sms

bin/animated_sprites.o: *.asm data/*.asm
	wla-z80 -o bin/animated_sprites.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
