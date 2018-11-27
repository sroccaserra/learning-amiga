; Learning the Amiga system

        move.b #10,d1
        move.w d1,$dff180

mainloop:
        add #254,d1

waitras1:
        move.w d1,$dff180
        cmp.b $dff006,d1
        bne waitras1
        move.w #$fff,$dff180

waitras2:
        cmp.b $dff006,d1
        beq waitras2
        move.w d1,$dff180

        btst #6,$bfe001
        bne mainloop

        rts
