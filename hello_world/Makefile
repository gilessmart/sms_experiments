bin/hello_world.sms: bin/hello_world.o
	wlalink -d -r -v -s linkfile bin/hello_world.sms

bin/hello_world.o: *.asm data/*.asm
	wla-z80 -o bin/hello_world.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
