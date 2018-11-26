; Rolling image on copperbars-1

DMACONR     EQU     $dff002
ADKCONR     EQU     $dff010
INTENAR     EQU     $dff01c
INTREQR     EQU     $dff01e

DMACON      EQU     $dff096
ADKCON      EQU     $dff09e
INTENA      EQU     $dff09a
INTREQ      EQU     $dff09c

    incdir "windows:amigavikke/"

; Optimizations could easily be made to the small/tight loops in the code by using incremental addressing (An)+ or decremental addressing -(An) and REPT <n> / ERPT

init:
; store hardware registers, store view- and copperaddresses, load blank view, wait 2x for top of frame, own blitter, wait for blitter AND finally forbid multitasking!
; all this just to be able to exit gracely

    ; store data in hardwareregisters ORed with $8000 (bit 15 is a write-set bit when values are written back into the system)
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

    move.l  $4,a6               ; execBase ==> a6
    move.l  #gfxname,a1         ; pointer to gfxname ==> a1 : used in openLibrary
    moveq   #0,d0               ; d0 = 0 any version of graphics.library will do
    jsr -552(a6)                ; d0 = openLibrary(a1,d0)
    move.l  d0,gfxbase          ; store the returned pointer ==> gfxbase
    move.l  d0,a6               ; d0 ==> a6 : a6 used as addressing base below
    move.l  34(a6),oldview      ; store old Viewport
    move.l  38(a6),oldcopper    ; store old Copperlist

    move.l #0,a1
    jsr -222(a6)    ; LoadView
    jsr -270(a6)    ; WaitTOF
    jsr -270(a6)    ; WaitTOF
    jsr -456(a6)    ; OwnBlitter
    jsr -228(a6)    ; WaitBlit
    move.l  $4,a6
    jsr -132(a6)    ; Forbid

; end exit gracely preparations!

    ; clear Bitplanes from garbage - very slow routine! should be done with the Blitter, or unrolled loop
    move.w #320/8*200/4,d0  ; d0 is a counter for number of longwords to get cleared
    move.l #bpl0,a0     ; bpl0 => a0
    move.l #bpl1,a1     ; bpl1 => a1
    screen_clear:
        move.l #0,(a0)+ ; #0 => (a0), and increment a0 to next longword (a0=a0+4)
        move.l #0,(a1)+ ; #0 => (a1), and increment a1 to next longword (a1=a1+4)
        subq.w #1,d0
        bne screen_clear

    ; copy bitmap to bitplanes
    move.w #320/8*94/4,d0
    move.l #bpl0,a0     ; bpl0 => a0
    move.l #bpl1,a1     ; bpl1 => a1
    move.l #img_av,a6
    add.l #2,a6
    copy_img:
        move.l 320/8*94(a6),(a1)+   ; bpl1
        move.l (a6)+,(a0)+              ; bpl0
        subq.w #1,d0
        bne copy_img

; setup displayhardware to show a 320x200px 2 bitplanes playfield, with zero horizontal scroll and zero modulos
    move.w  #$2200,$dff100              ; 2 bitplane lowres
    move.w  #$0000,$dff102              ; horizontal scroll 0
    move.w  #$0000,$dff108              ; odd modulo 0
    move.w  #$0000,$dff10a              ; even modulo 0
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


; *********************************************************
;
; 32px high copperbars for rolling (p=32*pi ==> p~100 ==> image should be ~ 100px high (here 94px)
;
; *********************************************************

    clr.l d1                    ; d0 = 0
    move.w cbar_img_line1,d1    ; startingline index ==> d1
    add.w #40,d1                ; d1 = d1 + 40 (320px/8 = 40 bytes)
    cmp.w #94/2*40,d1           ; compare if larger than half the height of the image
    bcs .10
    sub.w #94/2*40,d1           ; if it is, then subract the overgoing part from it
    .10:
    move.w d1,cbar_img_line1    ; store new startingline index for next frame

; if all copperbars below would have the same startingline in the image every bar would look the same,
; except for the background color.
; by chaning the startingline we get a "waggling" effect between the copperbarimages

    ; 1st bar
    move.l d1,d3                ; startingline in image ==> d3
    add.l #40*2,d3              ; add 2 lines to d3
    move.l #$2c,d2              ; starting scanline ==> d2
    move.l #cbar3,a0            ; colortable ==> a0
    jsr make_Copper_roller      ; Jump to SubRoutine (rts will get execution of code back here)

    ; 2nd bar
    move.l d3,d1
    add.l #40*4,d3              ; add 4 lines to d3
    move.l #$2c+$20,d2
    move.l #cbar2,a0
    jsr make_Copper_roller

    ; 3rd bar
    move.l d3,d1
    add.l #40*6,d3              ; add 6 lines to d3
    move.l #$2c+$40,d2
    move.l #cbar3,a0
    jsr make_Copper_roller

    ; 4th bar
    move.l d3,d1
    add.l #40*8,d3              ; add 8 lines to d3
    move.l #$2c+$60,d2
    move.l #cbar2,a0
    jsr make_Copper_roller

    ; 5th bar
    move.l d3,d1
    add.l #40*10,d3             ; add 10 lines to d3
    move.l #$2c+$80,d2
    move.l #cbar3,a0
    jsr make_Copper_roller


    ; end of copperlist (copperlist ALWAYS ends with WAIT $fffffffe)
    move.l #$fffffffe,(a6)+     ; end copperlist

testMouseButton:
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

    ; use next copperlist - as we are using doubblebuffering on copperlists we now take the new one into use
    move.l copper,d0
    move.l d0,$dff080
    bra mainloop

exit:
; exit gracely - reverse everything done in init
    move.w #$7fff,DMACON        ; set bits[0,14] = 0 (bit15 is a set/clear bit)
    move.w  olddmareq,DMACON    ; and set bits[0,14] as they were at init
    move.w #$7fff,INTENA        ; set bits[0,14] = 0 (bit15 is a set/clear bit)
    move.w  oldintena,INTENA    ; and set bits[0,14] as they were at init
    move.w #$7fff,INTREQ        ; set bits[0,14] = 0 (bit15 is a set/clear bit)
    move.w  oldintreq,INTREQ    ; and set bits[0,14] as they were at init
    move.w #$7fff,ADKCON        ; set bits[0,14] = 0 (bit15 is a set/clear bit)
    move.w  oldadkcon,ADKCON    ; and set bits[0,14] as they were at init

    move.l  oldcopper,$dff080   ; load old Copperlist
    ; graphics.library calls
    move.l  gfxbase,a6  ; gfxBase ==> a6
    move.l  oldview,a1  ; oldView ==> a1 (used in LoadView)
    jsr -222(a6)        ; LoadView : load back the view at start of program
    jsr -270(a6)        ; WaitTOF : Wait for Top Of Frame to get everything synced up
    jsr -270(a6)        ; WaitTOF : (2 times for interlaced screens)
    jsr -228(a6)        ; WaitBlit : wait for Blitter to finish running task (if any)
    jsr -462(a6)        ; DisownBlitter : release Blitter to system
    ; exec.library calls
    move.l  $4,a6       ; execBase ==> a6
    move.l  gfxbase,a1  ; gfxBase ==> a1 (used in closeLibrary)
    jsr -414(a6)        ; closeLibrary : close graphics.library
    jsr -138(a6)        ; Permit multitasking

    ; end program
    rts

; subroutines

make_Copper_roller:
    ; bitplane 0
    move.l #bpl0,d0
    add.l d1,d0         ; add startingline index to address
    move.w #$00e2,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e2
    swap d0
    move.w #$00e0,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e0

    ; bitplane 1
    move.l #bpl1,d0
    add.l d1,d0         ; add startingline index to address
    move.w #$00e6,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e6
    swap d0
    move.w #$00e4,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e4

    ;move.l #cbar2,a0
    move.l #cbar_c1,a1
    move.l #cbar_c2,a2
    move.l #cbar_c3,a3
    move.l #shift1,a4
    move.l #$0007fffe,d1        ; this is just a template for copper WAIT-instruction
                                ; to this template we need to add the vertical-position
                                ; into bits [24,31], 07 is the horizontal-position
    lsl.l #8,d2                 ; d2 = d2 * 2^8 (shift bits 8 steps left)
    lsl.l #8,d2                 ; d2 = d2 * 2^8 (8 is max shift, so therefore 3 times)
    lsl.l #8,d2                 ; d2 = d2 * 2^8 ==> all-in-all d2 = d2 * 2^24 
                                ; *2^24 could be made faster, but as this isn't timecritical
                                ; it isn't done here (this part is ran only once/bar/frame)
    add.l d2,d1                 ; add d2 to d1 = add vertical-position to the template
                                ; Copper WAIT <$Yy07>,<$fffe>: V:$Yy & H:$07 & mask:$fffe
    moveq #32,d0
    loop_cbar1:
        move.l d1,(a6)+     ; copper WAIT
        move.w #$0180,(a6)+ ; color0-
        move.w (a0)+,(a6)+  ;        value
        move.w #$0182,(a6)+ ; color1-
        move.w (a1)+,(a6)+  ;        value
        move.w #$0184,(a6)+ ; color2-
        move.w (a2)+,(a6)+  ;        value
        move.w #$0186,(a6)+ ; color3-
        move.w (a3)+,(a6)+  ;        value
        move.w #$0102,(a6)+ ; h-shift-
        move.w (a4)+,(a6)+  ;         value
        add.l #1<<24,d1     ; here the optimization continues,
                            ; we know that the verticalvalues are in bits[24,31],
                            ; so we add 1*2^24 to get to the next line
        subq #1,d0
        bne loop_cbar1

    rts                     ; end subroutine and get back to main code



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
gfxname:        dc.b 'graphics.library',0

    CNOP 0,4
cbar1:      dc.w $000,$100,$200,$300,$400,$500,$600,$700,$800,$900,$a00,$b00,$c00,$d00,$e00,$f00,$f00,$e00,$d00,$c00,$b00,$a00,$900,$800,$700,$600,$500,$400,$300,$200,$100,$000
cbar2:      dc.w $000,$101,$202,$303,$404,$505,$606,$707,$808,$909,$a0a,$b0b,$c0c,$d0d,$e0e,$f0f,$f0f,$e0e,$d0d,$c0c,$b0b,$a0a,$909,$808,$707,$606,$505,$404,$303,$202,$101,$000
cbar3:      dc.w $000,$001,$002,$003,$004,$005,$006,$007,$008,$009,$00a,$00b,$00c,$00d,$00e,$00f,$00f,$00e,$00d,$00c,$00b,$00a,$009,$008,$007,$006,$005,$004,$003,$002,$001,$000

cbar_c1:    dc.w $000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000
cbar_c2:    dc.w $000,$100,$200,$300,$400,$500,$600,$700,$800,$900,$A00,$B00,$C00,$D00,$E00,$F00,$F00,$E00,$D00,$C00,$B00,$A00,$900,$800,$700,$600,$500,$400,$300,$200,$100,$000
cbar_c3:    dc.w $000,$110,$220,$330,$440,$550,$660,$770,$880,$990,$AA0,$BB0,$CC0,$DD0,$EE0,$FF0,$FF0,$EE0,$DD0,$CC0,$BB0,$AA0,$990,$880,$770,$660,$550,$440,$330,$220,$110,$000
cbar_img_line1: dc.w 0

;shift1:        dc.w $00,$11,$33,$44,$66,$77,$99,$AA,$BB,$CC,$DD,$EE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$EE,$DD,$CC,$BB,$AA,$99,$77,$66,$44,$33,$11,$00
shift1:     dc.w $00,$55,$77,$99,$AA,$BB,$CC,$DD,$DD,$EE,$EE,$EE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$EE,$EE,$EE,$DD,$DD,$CC,$BB,$AA,$99,$77,$55,$00


    Section ChipRAM,Data_c

; bitplanes aligned to 32-bit
    CNOP 0,4
bpl0:   blk.b 320/8*250,0
bpl1:   blk.b 320/8*250,0

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
img_av: incbin "av.raw"
