; Learning the Amiga system

init:
        move.w  #$ac,d7         ; start y position of rasterline
        move.w  #1,d6           ; y increment

*******************************
mainloop:
waitframe:
        cmp.b   #$ff,$dff006
        bne     waitframe

;------ Frame loop start ------

        add     d6,d7           ; increment y position of rasterline

waitras1:
        cmp.b   $dff006,d7
        bne     waitras1
        move.w  #$fff,$dff180   ; set color 0 to white (draws a white line)

waitras2:
        cmp.b   $dff006,d7
        beq     waitras2
        move.w  #$116,$dff180   ; set color 0 to blue

;------ Frame loop end --------

        btst    #6,$bfe001
        bne     mainloop
*******************************
        rts
