bin/static_sprites.sms: bin/static_sprites.o
	wlalink -d -r -v -s linkfile bin/static_sprites.sms

bin/static_sprites.o: *.asm data/*.asm
	wla-z80 -o bin/static_sprites.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
