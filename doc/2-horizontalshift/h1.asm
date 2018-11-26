; Copperbars-1

DMACONR     EQU     $dff002
ADKCONR     EQU     $dff010
INTENAR     EQU     $dff01c
INTREQR     EQU     $dff01e

DMACON      EQU     $dff096
ADKCON      EQU     $dff09e
INTENA      EQU     $dff09a
INTREQ      EQU     $dff09c

    incdir "windows:amigavikke/"


; MACROS
; Macros are used to make it easier and shorter to read the code.
; Every time you see a marcocall in the code, you can think of it more-or-less like a copy-paste of the Macro-code
; (the only difference is the usage of local labels in the macros, as otherwise double-labeling would occour).

get_and_set_modulo: MACRO
        ; d7 is the linecounter
        ; d2 is the shiftvalue
        ; a6 is the copperlist pointer
        ; TRASH: d4
        btst.l #0,d7            ; test to see if bit0 is set
                                ; (if not set, even scanline ==> next scanline shaky possible)
        beq \@normal_hshift_80
        cmpi.b #1,hshift_mode   ; is hshift_mode is normal or shaky
        bne \@normal_hshift_80
        move.b #79,d4           ; shift = 79 - realshift
        sub.b d2,d4
        move.b d4,d2            ; and result aligned to match rest of the code
        \@normal_hshift_80:
        and.l #$70,d2       ; only bits 4, 5 & 6
        lsr.b #4,d2         ; 4LSB cut-off
        lsl.b #1,d2         ; *2 for b to w addressing
        cmp.b d0,d2
        beq \@modulo_1      ; if modulo = d2 ==> modulo_1
        move.b #8,d4        ; otherwise make moduloshifting, either left or right
        add.b d0,d4
        sub.b d2,d4
        move.w #$0108,(a6)+     ; these modulovalues are put into the registers on the scanline before
                                ; the line that will use them as modulo is only used at HorizontalBlanking
        move.w d4,(a6)+
        move.w #$010a,(a6)+     ; these modulovalues are put into the registers on the scanline before
                                ; the line that will use them as modulo is only used at HorizontalBlanking
        move.w d4,(a6)+
        move.b d2,d0
        bra \@modulo_0
        \@modulo_1:                     ; modulo = d2
        move.l #$01080008,(a6)+         ; set modulo = 8, the default value in this demo
        move.l #$010a0008,(a6)+         ; set modulo = 8, the default value in this demo
        \@modulo_0:
        ENDM

WAIT_nextline:  MACRO
    ; d7 is the linecounter
    ; d3 is the startline
    ; a6 is the copperlist pointer
    ; TRASH: d4
    move.w d7,d4        ; d4=d7
    add.w d3,d4         ; d4=d7+d3 (d7+startline)
    lsl.w #8,d4         ; d4=(d7+startline)*256
    add.w #$07,d4       ; d4=(d7+startline)<<256+07
    move.w d4,(a6)+     ; Wait - first line, ex: $6407
    move.w #$fffe,(a6)+ ; Mask
    ENDM

init:
; store hardware registers, store view- and copperaddresses, load blank view, wait 2x for top of frame,
; own blitter, wait for blitter AND finally forbid multitasking!
; all this just to be able to exit gracely

    ; store data in hardwareregisters ORed with $8000 (bit 15 is a write-set bit when
    ; values are written back into the system)
    move.w  DMACONR,d0
    or.w #$8000,d0
    move.w d0,olddmareq
    move.w  INTENAR,d0
    or.w #$8000,d0
    move.w d0,oldintena
    move.w  INTREQR,d0
    or.w #$8000,d0
    move.w d0,oldintreq
    move.w  ADKCONR,d0
    or.w #$8000,d0
    move.w d0,oldadkcon

    move.l  $4,a6
    move.l  #gfxname,a1
    moveq   #0,d0
    jsr -408(a6)    ; oldOpenLibrary offset=-408 ... would OpenLibrary be better? offset=-552
    move.l  d0,gfxbase
    move.l  d0,a6
    move.l  34(a6),oldview
    move.l  38(a6),oldcopper

    move.l #0,a1
    jsr -222(a6)    ; LoadView
    jsr -270(a6)    ; WaitTOF
    jsr -270(a6)    ; WaitTOF
    jsr -456(a6)    ; OwnBlitter
    jsr -228(a6)    ; WaitBlit
    move.l  $4,a6
    jsr -132(a6)    ; Forbid

; end exit gracely preparations!

    ; clear Bitplanes from garbage - slow routine! should be done with the Blitter,
    ; or as an partly unrolled loop if used in the mainloop
    move.w #384/8*200/4,d0  ; d0 is a counter for number of longwords to get cleared
    move.l #bpl0,a0     ; bpl0 => a0
    move.l #bpl1,a1     ; bpl1 => a1
    move.l #bpl2,a2     ; bpl2 => a2
    move.l #bpl3,a3     ; bpl3 => a3
    screen_clear:
        move.l #0,(a0)+ ; #0 => (a0), and increment a0 to next longword (a0=a0+4)
        move.l #0,(a1)+ ; #0 => (a1), and increment a1 to next longword (a1=a1+4)
        move.l #0,(a2)+ ; #0 => (a2), and increment a2 to next longword (a2=a2+4)
        move.l #0,(a3)+ ; #0 => (a3), and increment a3 to next longword (a3=a3+4)
        subq.w #1,d0
        bne screen_clear

    ; copy bitmap to bitplanes (384 x 90 px - 4 bitplanes)
    move.w #384/8*90/4,d0
    move.l #bpl0,a0     ; bpl0 => a0
    move.l #bpl1,a1     ; bpl1 => a1
    move.l #bpl2,a2     ; bpl2 => a2
    move.l #bpl3,a3     ; bpl3 => a3
    move.l #img_amigavikke,a6
    add.l #8,a6
    copy_img1:
        move.l 384/8*90*3(a6),(a3)+     ; bpl3
        move.l 384/8*90*2(a6),(a2)+     ; bpl2
        move.l 384/8*90*1(a6),(a1)+     ; bpl1
        move.l (a6)+,(a0)+              ; bpl0
        subq.w #1,d0
        bne copy_img1

    ; copy bitmap to bitplanes (384 x 90 px - 4 bitplanes)
    move.w #384/8*90/4,d0
    move.l #bpl0+384/8*110,a0   ; bpl0 => a0
    move.l #bpl1+384/8*110,a1   ; bpl1 => a1
    move.l #bpl2+384/8*110,a2   ; bpl2 => a2
    move.l #bpl3+384/8*110,a3   ; bpl3 => a3
    move.l #img_amigavikke,a6
    add.l #12,a6
    copy_img2:
        move.l 384/8*90*3(a6),(a3)+     ; bpl3
        move.l 384/8*90*2(a6),(a2)+     ; bpl2
        move.l 384/8*90*1(a6),(a1)+     ; bpl1
        move.l (a6)+,(a0)+              ; bpl0
        subq.w #1,d0
        bne copy_img2

; setup displayhardware to show a 320x200px 4 bitplanes playfield,
; with zero horizontal scroll and zero modulos
; setup displayhardware to show a 320x200px 4 bitplanes view,
; but with a playfield size of 384x200, h-scroll=0, modulo=(384-320)/8=8
    move.w  #$4200,$dff100              ; 4 bitplane lowres
    move.w  #$0000,$dff102              ; horizontal scroll 0
    move.w  #$0008,$dff108              ; odd modulo 8
    move.w  #$0008,$dff10a              ; even modulo 8
    move.w  #$2c81,$dff08e              ; DIWSTRT - topleft corner (2c81)
    move.w  #$f4d1,$dff090              ; DIVSTOP - bottomright corner (f4d1)
    move.w  #$0038,$dff092              ; DDFSTRT - max overscan $0018 ; standard 0038 & 00d0
    move.w  #$00d0,$dff094              ; DDFSTOP - max overscan $00d8 ; max overscan: 368x283px in PAL
    move.w  #%1000010111000000,DMACON   ; DMA set ON
    move.w  #%0000000000111111,DMACON   ; DMA set OFF
    move.w  #%1100000000000000,INTENA   ; IRQ set ON
    move.w  #%0011111111111111,INTENA   ; IRQ set OFF


mainloop:
; increase framecounter by 1
    move.l frame,d0
    addq.l #1,d0
    move.l d0,frame

; change effect settings according to framecounter
    ; normal or "shaky" Hshift
    move.l d0,d1
    and.l #$1ff,d1          ; 511/50 ~ 10sec => every 10 sec speed changes +1, in interval [2,5]
    bne .10
    eori.b #1,hshift_mode
    .10:


; make copperlist
; doubblebuffering of copperlists, defined at copper1 and copper2, chosen by LSB in framecounter
; copper (and a6) will hold the address to the copperlist we will write to (not the one currently in use)
    and.l #1,d0
    bne usecopper2
    move.l #copper1,a6
    bra usecopper1
    usecopper2:
    move.l #copper2,a6
    usecopper1:
    move.l a6,copper

    ; bitplane 0
    move.l #bpl0,d0
    move.w #$00e2,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e2
    swap d0
    move.w #$00e0,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e0

    ; bitplane 1
    move.l #bpl1,d0
    move.w #$00e6,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e6
    swap d0
    move.w #$00e4,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e4

    ; bitplane 2
    move.l #bpl2,d0
    move.w #$00ea,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e2
    swap d0
    move.w #$00e8,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e0

    ; bitplane 3
    move.l #bpl3,d0
    move.w #$00ee,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e6
    swap d0
    move.w #$00ec,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e4

    ; colors
    move.l #$01800000,(a6)+ ; color 0: $000 into $dff180
    move.l #$01820000,(a6)+ ; color 1: $000 into $dff182
    move.l #$01840f00,(a6)+ ; color 2: $f00 into $dff184
    move.l #$01860f10,(a6)+ ; color 3: $fff into $dff186
    move.l #$01880f20,(a6)+ ; color 4: $000 into $dff188
    move.l #$018a0f30,(a6)+ ; color 5: $000 into $dff18a
    move.l #$018c0f40,(a6)+ ; color 6: $f00 into $dff18c
    move.l #$018e0f60,(a6)+ ; color 7: $fff into $dff18e
    move.l #$01900f70,(a6)+ ; color 8: $000 into $dff190
    move.l #$01920f80,(a6)+ ; color 9: $000 into $dff192
    move.l #$01940f90,(a6)+ ; color 10: $f00 into $dff194
    move.l #$01960fb0,(a6)+ ; color 11: $fff into $dff196
    move.l #$01980fc0,(a6)+ ; color 12: $000 into $dff198
    move.l #$019a0fd0,(a6)+ ; color 13: $000 into $dff19a
    move.l #$019c0fe0,(a6)+ ; color 14: $f00 into $dff19c
    move.l #$019e0ff0,(a6)+ ; color 15: $fff into $dff19e

    ; horizontal scroll
    move.l #$01020000,(a6)+ ; 0 for both odd and even numbered bpl (rightmost 2 zeros)


; *******************************
;
; 16 px horizontal shift - Amigas hardware can do it without any tricks
;
; *******************************

    move.l frame,d1         ; d1 is an anglespeed-value, here we give it the same value as the framecounter,
    lsl.l #2,d1             ; and multiply it by 2^2 = 4 (changing this multiplier will affect the starting angle)
    and.l #$ff,d1           ; and lastly we have to align it to be a byte value, as our sinus-table only has 256 values!
    move.l #sin255_15,a0
    move.l #colorcodes,a1
    move.b #44,d3
    move.l #0,d7
    loop_16px_hshift:
        WAIT_nextline       ; macro
        ; copper MOVE-instruction generation
        move.w #$0180,(a6)+
        move.w (a1)+,(a6)+
        move.b (a0,d1),d2

        btst.l #0,d7            ; test to see if bit0 is set (if set, odd scanline ==> shaky possible)
        bne normal_hshift16
        cmpi.b #1,hshift_mode   ; is hshift_mode is normal or shaky
        bne normal_hshift16
        move.b #$f,d4           ; shift = 15 - realshift
        sub.b d2,d4
        move.b d4,d2            ; and result aligned to match rest of the code
        normal_hshift16:

        move.b d2,d4            ; replicate value in bits[0,3] to bits[4,7]
        lsl.b #4,d2             
        add.b d4,d2
        move.w #$0102,(a6)+     ; horizontal scroll
        move.w d2,(a6)+         ; value 
        addq #4,d1              ; d1 is an anglespeed-value giving longer or shorter sinuscurves
        and.l #$ff,d1
        addq #1,d7
        cmp.b #90,d7
        bne loop_16px_hshift

    WAIT_nextline               ; macro
    move.l #$01800000,(a6)+
    move.l #$01020000,(a6)+


; *******************************
;
; 80 px horizontal shift - to get more than 16px horizontal scroll we need to apply modulos to the playfield
;
; *******************************



    move.l frame,d1         ; read above in 16px shift about anglespeed
;   lsl.l #1,d1             ; no multiplier used, thus the line is commented out of the source
    and.l #$ff,d1
    move.l #sin255_79,a0
    move.l #colorcodes,a1
    move.b #0,d0            ; d0 stores modulo value
    move.b #153,d3          ; startline - !!!! needs to start one line before the actual
                            ; image to get modulovalues correct (should be an empty line) !!!!
    move.l #0,d7
    loop_80px_hshift:
        WAIT_nextline       ; macro
        ; copper MOVE-instruction generation
        move.w #$0180,(a6)+
        move.w (a1)+,(a6)+
        move.b (a0,d1),d2

        btst.l #0,d7            ; test to see if bit0 is set (if set, odd scanline ==> shaky possible)
        bne normal_hshift80
        cmpi.b #1,hshift_mode   ; is hshift_mode is normal or shaky
        bne normal_hshift80
        move.b #79,d4           ; shift = 79 - realshift
        sub.b d2,d4
        move.b d4,d2            ; and result aligned to match rest of the code
        normal_hshift80:

        and.b #$f,d2            ; get bits[0,3] of scrollvalue ==> these are used for Hscroll-value
        move.b d2,d4            ; and then replicated to bits[4,7] 
        lsl.b #4,d2
        add.b d4,d2
        move.w #$0102,(a6)+     ; horizontal scroll
        move.w d2,(a6)+         ; value 
        addq #1,d1              ; d1 is an anglespeed-value giving longer or shorter sinuscurves
        and.l #$ff,d1

        ;look at next lines scrollvalue - needed to calculate modulovalues for the next scanline
        moveq #0,d4
        move.b (a0,d1),d2
        get_and_set_modulo      ; macro

        addq #1,d7
        cmp.b #91,d7            ; counter has to be height of image +1, because of the extra line at the beginning!!!
        bne loop_80px_hshift

    ; HACK used to "undo" last changes to the copperlist, the pointer is moved 2 instructions back
    ; (faster than checking for last line every time)
    sub.l #4,a6     ; removing two MOVE-instructions intended for the next scanline,
                    ; but not wanted anymore as all lines have already been iterated 

    ; make WAIT-instruction for the next line
    WAIT_nextline
    move.l #$01800000,(a6)+
    move.l #$01020000,(a6)+
    move.l #$01080008,(a6)+
    move.l #$010a0008,(a6)+
    ; If you want to display parts of the bitplanes after the horizontal-moduloshifting process,
    ; the easiest way to get it to work correctly is to set up the the bitplane-pointers again,
    ; with newly calculated startingpoints and using the standard modulo-value.
    ; However, easiest would be to setup a whole new screen, with its own bitplanes and modulos.
    ; An empty line after the Hshifting area is a good idea, as you might have to change
    ; a lot of different hardwareregisters!
    ; The empty lines before and after Hshifting area are possible to remove by changing the code,
    ; but then the code will be a lot harder to read, and this is a part of a tutorial-series.

    ; end of copperlist (copperlist ALWAYS ends with WAIT $fffffffe)
    move.l #$fffffffe,(a6)+     ; end copperlist


    ; if mousebutton/joystick 1  or 2 pressed then exit
    btst.b #6,$bfe001
    beq exit
    btst.b #7,$bfe001
    beq exit

; display is ready, or atleast we have done everything we wanted and the copper continues on its own
; we have to wait for Vertical Blanking before making the next frame

waitVB:
    move.l $dff004,d0
    and.l #$1ff00,d0
    cmp.l #300<<8,d0
    bne waitVB

    ; use next copperlist - as we are using doubblebuffering on copperlists
    ; we now take the new one into use
    move.l copper,d0
    move.l d0,$dff080
    bra mainloop

exit:
; exit gracely - reverse everything done in init
    move.w #$7fff,DMACON
    move.w  olddmareq,DMACON
    move.w #$7fff,INTENA
    move.w  oldintena,INTENA
    move.w #$7fff,INTREQ
    move.w  oldintreq,INTREQ
    move.w #$7fff,ADKCON
    move.w  oldadkcon,ADKCON

    move.l  oldcopper,$dff080
    move.l  gfxbase,a6
    move.l  oldview,a1
    jsr -222(a6)    ; LoadView
    jsr -270(a6)    ; WaitTOF
    jsr -270(a6)    ; WaitTOF
    jsr -228(a6)    ; WaitBlit
    jsr -462(a6)    ; DisownBlitter
    move.l  $4,a6
    jsr -138(a6)    ; Permit

    ; end program
    rts



; *******************************************************************************
; *******************************************************************************
; DATA
; *******************************************************************************
; *******************************************************************************


; storage for 32-bit addresses and data
    CNOP 0,4
oldview:    dc.l 0
oldcopper:  dc.l 0
gfxbase:    dc.l 0
frame:      dc.l 0
copper:     dc.l 0

; storage for 16-bit data
    CNOP 0,4
olddmareq:  dc.w 0
oldintreq:  dc.w 0
oldintena:  dc.w 0
oldadkcon:  dc.w 0

    CNOP 0,4
; storage for 8-bit data and text
gfxname:    dc.b 'graphics.library',0
sin255_15:  dc.b 8,8,8,8,8,8,9,9,9,9,9,10,10,10,10,10,10,11,11,11,11,11,11,12,12,12,12,12,12,12,13,13,13,13,13,13,13,13,14,14,14,14,14,14,14,14,14,14,14,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,14,14,14,14,14,14,14,14,14,14,14,13,13,13,13,13,13,13,13,12,12,12,12,12,12,12,11,11,11,11,11,11,10,10,10,10,10,10,9,9,9,9,9,9,8,8,8,8,8,7,7,7,7,7,6,6,6,6,6,6,5,5,5,5,5,5,4,4,4,4,4,4,3,3,3,3,3,3,3,2,2,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,2,2,2,3,3,3,3,3,3,3,4,4,4,4,4,4,5,5,5,5,5,5,6,6,6,6,6,7,7,7,7,7,8
sin255_79: dc.b 40,41,42,43,44,45,46,47,48,49,50,50,51,52,53,54,55,56,57,58,58,59,60,61,62,63,63,64,65,66,66,67,68,68,69,70,70,71,71,72,73,73,74,74,74,75,75,76,76,76,77,77,77,78,78,78,78,78,79,79,79,79,79,79,79,79,79,79,79,79,79,78,78,78,78,78,77,77,77,76,76,76,75,75,74,74,73,73,72,72,71,71,70,69,69,68,67,67,66,65,64,64,63,62,61,61,60,59,58,57,56,55,55,54,53,52,51,50,49,48,47,46,45,44,43,42,41,40,40,39,38,37,36,35,34,33,32,31,30,29,28,27,26,25,25,24,23,22,21,20,19,19,18,17,16,16,15,14,13,13,12,11,11,10,9,9,8,8,7,7,6,6,5,5,4,4,4,3,3,3,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,2,2,2,2,2,3,3,3,4,4,4,5,5,6,6,6,7,7,8,9,9,10,10,11,12,12,13,14,14,15,16,17,17,18,19,20,21,22,22,23,24,25,26,27,28,29,30,30,31,32,33,34,35,36,37,38,39,40


hshift_mode:    dc.b 0
modulo:         dc.b 0
modulo_flag:    dc.b 0

    CNOP 0,4
colorcodes: dc.w $000,$001,$002,$003,$004,$005,$006,$007,$008,$009,$00A,$00B,$00C,$00D,$00E,$00F,$00E,$00D,$00C,$00B,$00A,$009,$008,$007,$006,$005,$004,$003,$002,$001,$000,$011,$022,$033,$044,$055,$066,$077,$088,$099,$0AA,$0BB,$0CC,$0DD,$0EE,$0FF,$0EE,$0DD,$0CC,$0BB,$0AA,$099,$088,$077,$066,$055,$044,$033,$022,$011,$000,$010,$020,$030,$040,$050,$060,$070,$080,$090,$0A0,$0B0,$0C0,$0D0,$0E0,$0F0,$0E0,$0D0,$0C0,$0B0,$0A0,$090,$080,$070,$060,$050,$040,$030,$020,$010,$000



    CNOP 0,4
copperlines1:   blk.w 100,0



    Section ChipRAM,Data_c

; bitplanes aligned to 32-bit
    CNOP 0,4
bpl0:   blk.b 384/8*200,0
bpl1:   blk.b 384/8*200,0
bpl2:   blk.b 384/8*200,0
bpl3:   blk.b 384/8*200,0


; datalists aligned to 32-bit
    CNOP 0,4
copper1:    
            dc.l $ffffffe   ; CHIPMEM!
            blk.l 1023,0    ; CHIPMEM!
    CNOP 0,4
copper2:    
            dc.l $ffffffe   ; CHIPMEM!
            blk.l 1023,0    ; CHIPMEM!

    CNOP 0,4
img_amigavikke: incbin "amigavikke_new.raw"

