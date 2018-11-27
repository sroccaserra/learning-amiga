;;
; Learning the Amiga system
;
; This code draws a horizontal moving white line across the screen.
;
; Watching this gentle tutorial series:
; - <https://www.youtube.com/watch?v=p83QUZ1-P10&list=PLc3ltHgmiidpK-s0eP5hTKJnjdTHz0_bW>

init:
        move    #$ac,d7         ; start y position of rasterline
        move    #1,d6           ; y increment
        move    $dff01c,d5      ; save interupt bits state in d5
        move    #$7fff,$dff09a  ; disable all bits in INTENA

*******************************
mainloop:
waitframe:
        btst    #0,$dff005      ; wait for most significant bit of vpos (V8) to be zero (frame flop)
        bne     waitframe
        cmp.b   #$2c,$dff006    ; wait for least significant bits of vpos (V7-V0) to equal #$2c
        bne     waitframe
        move    #$000,$dff180   ; set background color to black

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

waitras1:                       ; wait for vpos to reach rasterline postion
        cmp.b   $dff006,d7
        bne     waitras1
        move    #$fff,$dff180   ; set background color to white (draws a white line)

waitras2:                       ; wait for vpos to leave rasterline position
        cmp.b   $dff006,d7
        beq     waitras2
        move    #$000,$dff180   ; set background color to black

;------ Frame loop end --------

        btst    #6,$bfe001      ; is mouse button pressed?
        bne     mainloop
*******************************
exit:
        or      #$c000,d5
        move    d5,$dff09a      ; restore initial INTENA bits
        rts
