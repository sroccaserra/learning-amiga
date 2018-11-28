;;
; Learning the Amiga system
;
; This code draws a horizontal moving white line across the screen.
;
; Watching this gentle tutorial series:
; - <https://www.youtube.com/watch?v=p83QUZ1-P10&list=PLc3ltHgmiidpK-s0eP5hTKJnjdTHz0_bW>

init:
        move.l  4.w,a6          ; exec base
        clr.l   d0
        move.l  #gfxname,a1
        jsr     -552(a6)        ; call openLibrary: d0 = openLibrary(a1,d0)
        move.l  d0,a1           ; move result to a1
        move.l  38(a1),d4       ; save the original copper pointer to d4
        jsr     -414(a6)        ; call closelibrary()

        move    #$ac,d7         ; start y position of rasterline
        move    #1,d6           ; y increment
        move    $dff01c,d5      ; save interupt bits state in d5
        move    #$7fff,$dff09a  ; disable all bits in INTENA

        move.l  #Copper,$dff080 ; Point the copper pointer to the copper list

*******************************
mainloop:
waitframe1:
        btst    #0,$dff005      ; wait for most significant bit of vpos (V8) to be zero (frame flop)
        bne     waitframe1
        cmp.b   #$2a,$dff006    ; wait for least significant bits of vpos (V7-V0) to equal #$2c
        bne     waitframe1
waitframe2:
        cmp.b   #$2a,$dff006    ; loop is too fast, wait until we leave that scanline
        beq     waitframe2

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

        move.b  d7,waitras1     ; write rasterline vpos to copper list
        move    d7,d0
        add     #1,d0           ; compute next line vpos
        move.b  d0,waitras2     ; write next line vpos to copper list

;------ Frame loop end --------

        btst    #6,$bfe001      ; is mouse button pressed?
        bne     mainloop
*******************************
exit:
        move.l  d4,$dff080      ; restore original copper pointer
        or      #$c000,d5
        move    d5,$dff09a      ; restore initial INTENA bits
        rts

gfxname:
        dc.b "graphics.library",0

        SECTION tut,DATA_C      ; Allocate this section in chip memory, required by the copper
Copper:
        dc.w    $1fc,$0000      ; Slow fetch mode for AGA compatibility
        dc.w    $100,$0200      ; Turn off all the bitplanes (with color burst = on, for Amiga 1000)

        dc.w    $180,$349       ; set background color
        dc.w    $2b07,$fffe     ; wait for screen position
        dc.w    $180, $56c
        dc.w    $2c07,$fffe
        dc.w    $180, $113

waitras1:
        dc.w    $8007,$fffe     ; Beginning of white line position
        dc.w    $180, $fff
waitras2:
        dc.w    $8107,$fffe     ; Restore color on next line position
        dc.w    $180, $113

        dc.w    $ffdf,$fffe     ; wait past the first half of the screen (we have only 8 bits to express vpos here)
        dc.w    $2c07,$fffe
        dc.w    $180, $56c
        dc.w    $2d07,$fffe
        dc.w    $180, $349

        dc.w    $ffff,$fffe     ; End of copper list (wait for impossible position $ffff)
