bin/gamepad_tester.sms: bin/gamepad_tester.o
	wlalink -d -r -v -s linkfile bin/gamepad_tester.sms

bin/gamepad_tester.o: *.asm data/*.asm
	wla-z80 -o bin/gamepad_tester.o main.asm

.PHONY: clean

clean:
	rm bin/*.o bin/*.sms bin/*.sym
