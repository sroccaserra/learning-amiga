; Learning the Amiga system

init:
        move.w  #$ac,d7         ; start y position of rasterline
        move.w  #1,d6           ; y increment

*******************************
mainloop:
waitframe:
        cmp.b   #$ff,$dff006    ; wait for vpos to equal #$ff
        bne     waitframe

;------ Frame loop start ------

        add     d6,d7           ; increment y position of rasterline

        cmp.b   #$f0,d7
        blo     ok1             ; is the line lower than #$f0?
        neg     d6              ; if not, negate increment (bounce on the bottom)
ok1:

        cmp.b   #$40,d7
        bhi     ok2
        neg     d6              ; same idea, but instead bounce on the top (line #$40)
ok2:

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
