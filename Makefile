objs = tile.o message.o mob.o dungeon.o generate.o random.o render.o input.o main.o

run: simplerl
	fceux simplerl.nes

simplerl: $(objs)
	ld65 -o simplerl.nes --config simplerl.cfg $(objs)

%.o: %.s
	ca65 -t nes $< -o $@

clean:
	rm simplerl.nes *.o
