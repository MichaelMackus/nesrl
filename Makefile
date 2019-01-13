objs = status.o ppu.o math.o item.o lighting.o ai.o player.o buffer.o tile.o \
	message.o mob.o dungeon.o generate.o random.o \
	sprite.o screen.o update.o render.o input.o main.o

run: simplerl
	fceux --xscale 3 --yscale 3 simplerl.nes

simplerl: $(objs)
	ld65 -o simplerl.nes --config simplerl.cfg $(objs)

%.o: %.s
	ca65 -t nes $< -o $@

clean:
	rm simplerl.nes *.o
