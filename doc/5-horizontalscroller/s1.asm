; Scrolly-1

DMACONR     EQU     $dff002
ADKCONR     EQU     $dff010
INTENAR     EQU     $dff01c
INTREQR     EQU     $dff01e

DMACON      EQU     $dff096
ADKCON      EQU     $dff09e
INTENA      EQU     $dff09a
INTREQ      EQU     $dff09c

BLTCON0     EQU     $dff040
BLTCON1     EQU     $dff042
BLTAFWM     EQU     $dff044
BLTALWM     EQU     $dff046
BLTCPTH     EQU     $dff048
BLTBPTH     EQU     $dff04C
BLTAPTH     EQU     $dff050
BLTDPTH     EQU     $dff054
BLTSIZE     EQU     $dff058
BLTBMOD     EQU     $dff062
BLTCMOD     EQU     $dff060
BLTAMOD     EQU     $dff064
BLTDMOD     EQU     $dff066

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
    move.w #352/8*200/4,d0  ; d0 is a counter for number of longwords to get cleared
    move.l #bpl0a,a0    ; bpl0a => a0
    move.l #bpl1a,a1    ; bpl1a => a1
    move.l #bpl0b,a2    ; bpl0b => a2
    move.l #bpl1b,a3    ; bpl1b => a3
    screen_clear:
        move.l #0,(a0)+ ; #0 => (a0), and increment a0 to next longword (a0=a0+4)
        move.l #0,(a1)+ ; #0 => (a1), and increment a1 to next longword (a1=a1+4)
        move.l #0,(a2)+ ; #0 => (a2), and increment a2 to next longword (a2=a2+4)
        move.l #0,(a3)+ ; #0 => (a3), and increment a3 to next longword (a3=a3+4)
        subq.w #1,d0
        bne screen_clear
        
; setup displayhardware to show a 352x200px 2 bitplanes playfield, with zero horizontal scroll and 4 modulos
    move.w  #$2200,$dff100              ; 2 bitplane lowres
    move.w  #$0000,$dff102              ; horizontal scroll 0
    move.w  #$0004,$dff108              ; odd modulo 4
    move.w  #$0004,$dff10a              ; even modulo 4
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

    move.l haltend,d1
    cmp.l d0,d1
    bne do_not_reset_halt
    move.b oldscrollspeed,scrollspeed
    move.b #0,halt_status
    do_not_reset_halt:


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

    cmp.b #1,halt_status
    bne halt_is_off
    move.l #1,d0
    halt_is_off:

    and.l #1,d0
    bne useBplB
    move.l #bpl0a,bpl0
    move.l #bpl1a,bpl1
    move.l #bpl0b,bpl0x
    move.l #bpl1b,bpl1x
    bra useBplA
    useBplB:
    move.l #bpl0b,bpl0
    move.l #bpl1b,bpl1
    move.l #bpl0a,bpl0x
    move.l #bpl1a,bpl1x
    useBplA:

    ; bitplane 0
    move.l bpl0,d0
    move.w #$00e2,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e2
    swap d0
    move.w #$00e0,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e0

    ; bitplane 1
    move.l bpl1,d0
    move.w #$00e6,(a6)+ ; LO-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e6
    swap d0
    move.w #$00e4,(a6)+ ; HI-bits of start of bitplane
    move.w d0,(a6)+     ; go into $dff0e4


    move.l #$01800000,(a6)+
    move.l #$01820000,(a6)+
    move.l #$01840226,(a6)+
    move.l #$01860448,(a6)+
    
    move.l #0,d7
    move.l #coppercolors,a5
    copper_colors:
        move.w d7,d6
        add.w #100+$2c,d6
        lsl.l #8,d6
        add.w #$07,d6
        move.w d6,(a6)+
        move.w #$fffe,(a6)+
        move.w #$0182,(a6)+
        move.l d7,d6
        lsl.l #1,d6
        move.w (a5,d6),(a6)+
        addq #1,d7
        cmp.l #25,d7
        bcs copper_colors


    ; end of copperlist (copperlist ALWAYS ends with WAIT $fffffffe)
    move.l #$fffffffe,(a6)+         ; end copperlist


    move.l #0,d0                    ; empty registers because of byte handling
    move.l #0,d1
    move.l #0,d2
    move.l #0,d3
    move.l #0,d4
    move.l #0,d5
    move.b scrollspeed,d0           ; scrollspeed ==> d0
    move.b scrollx,d1               ; counter for actual x-shift position
    move.b scrollflag,d2            ; this flag is needed because of 32px wide font
    add.b d0,d1                     ; scrollx = scrollx + scrollspeed
    cmp.b #16,d1 
    bcc .10
    sub.b #16,d1                    ; scrollx >=16 then scrollx=scrollx-16
    addq #1,d2                      ; and increment scrollflag by 1
    .10:
    move.b d1,scrollx               ; save scrollx-value
    move.b d2,scrollflag            ; save scrollflag-value
    cmp.b #2,d2                     ; if flag=2, then time to add next character into scroller
    bne scroll                      ; otherwise just scroll the scroller
    ; next character
    move.l #scrolltext,a0           ; scrolltext ==> a0
    move.l #font,a1                 ; font-image ==> a1
    move.l #charoffsets,a2          ; character offsets ==> a2
    move.l bpl0,a5
    add.l #100*44+40,a5
    move.l a5,a3                    ; bpl0 line 100 + offset ==> a3
    move.l bpl1,a5
    add.l #100*44+40,a5
    move.l a5,a4                    ; bpl1 line 100 + offset ==> a4
    move.w scrollcounter,d3         ; scrollcounter
    get_next_char:
    add.w #1,d3                     ; scrollcounter++
    move.w d3,scrollcounter         ; and store it
    move.b (a0,d3.w),d4             ; next character in scrolly (ASCII)
    cmp.b #-1,d4                    ; if -1, then restart scrolly from beginning
    bne not_EOT
    move.w #-1,d3                   ; set counter at -1, it will get added with +1 so it really is 0
    move.w d3,scrollcounter         ; and store it
    bra get_next_char
    not_EOT:
    cmp.b #0,d4                     ; if d4=0, change speed
    bne no_speedchange
    add.w #1,d3                     ; scrollcounter++
    move.w d3,scrollcounter         ; and store it
    move.l #0,d4
    move.b (a0,d3.w),d4             ; next character in scrolly (byte)
    cmp.b #0,d4                     ; if d4=0, halt
    bne change_speed
    add.w #1,d3                     ; scrollcounter++
    move.w d3,scrollcounter         ; and store it
    move.b (a0,d3.w),d4             ; next character in scrolly (byte)
    move.b d0,oldscrollspeed        ; oldscrollspeed = actual scrollspeed
    move.b #0,scrollspeed           ; scrollspeed = 0
    lsl.l #6,d4                     ; d4*2^6 (2^6=64, 64 frames = 64/50 sec = 1,28 s) 
    move.l frame,d0
    add.l d4,d0
    move.l d0,haltend               ; set haltend to actual frame + delay
    move.b #1,halt_status           ; set halt_status = 1
    bra get_next_char
    change_speed:
    move.b d4,d0                    ; new scrollspeed ==> d0
    move.b d0,scrollspeed           ; save scrollspeed for next frame
    no_speedchange:
    cmp.b #97,d4                    ; if ASCII >= 97 (97 == 'a')
    bcs under97
    sub.b #32,d4                    ; subtract 32 from ASCII ('a' ==> 'A' .. 'z' ==> 'Z')
    under97:
    cmp.b #91,d4                    ; maximum ASCII = 90, if over get next
    bcc get_next_char
    cmp.b #32,d4                    ; minimum ASCII = 32, if under get next
    bcs get_next_char               
    sub.b #32,d4                    ; first character in bitmap: ASCII 32
    lsl.b #1,d4                     ; *2, byte => word-alignment
    move.w (a2,d4.w),d5             ; charoffset for character
    move.l #25,d7                   ; loop 25 times (25 lines high font)
    copy_char:                      ; this copy-routine could be done using the Blitter,
                                    ; but the speedgain would not be very large, as the
                                    ; setup for the blit will in itself be many word/longword-moves
                                    ; done with the CPU the fontdata can reside in FastMem as well
                                    ; as ChipMem. 
    move.l d5,d6
    move.l (a1,d6.l),(a3)           ; font + offset ==> bpl0
    add.l #40*150*1,d6
    move.l (a1,d6.l),(a4)           ; font + offset ==> bpl1
    add.l #40,a1                    ; font-image width: 320px/8bits = 40 bytes
    add.l #44,a3                    ; bpl0, next line
    add.l #44,a4                    ; bpl1, next line
    subq #1,d7
    bne copy_char
    move.b #0,scrollflag            ; empty scrollflag
    
    scroll:
    move.l #0,d0
    move.b scrollspeed,d0           ; get scrollspeed 
    cmp.b #0,d0
    beq testMouseButton
    move.l #16,d1
    sub.l d0,d1                     ; 16 - scrollspeed
    lsl.l #8,d1                     ; shift left 12 bitpositions (8+4)
    lsl.l #4,d1                     ; as shiftvalue is in bits[12,15]
    add.l #$9f0,d1                  ; set usage of sources and minterm
                                    ; $9 = use sources A and D 
                                    ; $f0 = minterm = A

    ; move scrolly to the left
    move.l bpl0,a5                  ; source: bpl0
    add.l #44*100,a5                ; pixelline 100
    move.l a5,BLTAPTH               ; BLTAPTH - A pointer
    move.l bpl0x,a5                 ; destination: bpl0x
    add.l #44*100-2,a5              ; pixelline 100, and -2 bytes because of shifting
    move.l a5,BLTDPTH               ; BLTDPTH - D pointer
    move.w  #0,BLTAMOD              ; BLTAMOD - A modulo = 0
    move.w  #0,BLTDMOD              ; BLTDMOD - D modulo = 0
    move.w  d1,BLTCON0              ; BLTCON0 - set previously generated controlbits
    move.w  #0,BLTCON1              ; BLTCON1 - not used here
    move.w  #$ffff,BLTAFWM          ; BLTAFWM - mask $ffff
    move.w  #$ffff,BLTALWM          ; BLTALWM - mask $ffff
    move.w  #26<<6+22,BLTSIZE       ; BLTSIZE - 26 lines * 22 words + START BLIT

    ; we are using BlitterNasty, so we don't have to wait for the Blitter here,
    ; the CPU is stalled from access to ChipRAM until the Blitter is ready.
    ; without BlitterNasty a WaitBlitter-routine must be used!!!

    move.l bpl1,a5                  ; source: bpl1
    add.l #44*100,a5                ; pixelline 100
    move.l a5,BLTAPTH               ; BLTAPTH - A pointer
    move.l bpl1x,a5                 ; destination: bpl1x
    add.l #44*100-2,a5              ; pixelline 100 -2 bytes because of shifting
    move.l a5,BLTDPTH               ; BLTDPTH - D pointer
                                    ; BLTAMOD, BLTDMOD, BLTCON0, BLTCON1, BLTALWM and BLTAFWM
                                    ; unchanged ==> same as in the previous blit!
    move.w  #26<<6+22,BLTSIZE       ; BLTSIZE - 26 lines * 22 words + START BLIT
    
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
    cmp.l #303<<8,d0
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
haltend:    dc.l 0

; storage for 16-bit data
    CNOP 0,4
olddmareq:  dc.w 0
oldintreq:  dc.w 0
oldintena:  dc.w 0
oldadkcon:  dc.w 0

    CNOP 0,4
; storage for 8-bit data and text
gfxname:        dc.b 'graphics.library',0
author:         dc.b 'AmigaVikke',0
scrollx:        dc.b 0              ; startvalue = 0
scrollspeed:    dc.b 4              ; scrollspeed, 4 is a good value to start with
scrollflag:     dc.b 0              ; used as a flag to indicate if it is time to copy char
oldscrollspeed: dc.b 0              ; used to return from HALT
halt_status:    dc.b 0              ; 0 = no halt, 1 = halt
scrolltext:     dc.b 'This is AmigaVikke writing at the keyboard... this is how the old demos '
                dc.b 'told the reader who in the group was writing, '
                dc.b 'and more importantly who was sending greetings. So here we go: Greetings to '
                dc.b '..........',0,8,'.......... ',0,4,'everyone ',0,0,5,' following these tutorials!!!! '
                dc.b 'r e s t a r t i n g ... in ... 3 ... 2 ... 1 ... ',0,4
                dc.b -1,0           ; -1 marks the end of the text and the scoller restarts
                ; 0 indictes a speedchange, the next byte is the speed, ex: 0,2 = speed 2, 0,6 = speed 6
                ; 0,0 = speed 0 = HALT!!! the next byte indicates for how many seconds, ex: 0,0,5 = halt 5*1,28 sec.
                ; 0,[1,f] = speed [$1,$f]
                ; 0,0,[0,f] = speed 0, halt [$0,$f] seconds.


    ; Charoffset is a table for telling where each character starts
    ; each character is 4 bytes wide and 25 lines high, and there are 10 chars per line
    ; thus the chars o charline 1 starts at 0, 4, 8 etc bytes
    ; on charline 2, we get an additional offset of 40*25 = 1000
    ; (40 bytes per line * 25 lines high)
    ; then the next charline is 1000*2 = 2000 etc
    ; NOTICE! These values depend on the charset used!

    CNOP 0,4
charoffsets:    dc.w       0,    4,    8,   12,   16,   20,   24,   28,   32,   36
                dc.w    1000, 1004, 1008, 1012, 1016, 1020, 1024, 1028, 1032, 1036
                dc.w    2000, 2004, 2008, 2012, 2016, 2020, 2024, 2028, 2032, 2036
                dc.w    3000, 3004, 3008, 3012, 3016, 3020, 3024, 3028, 3032, 3036
                dc.w    4000, 4004, 4008, 4012, 4016, 4020, 4024, 4028, 4032, 4036
                dc.w    5000, 5004, 5008, 5012, 5016, 5020, 5024, 5028, 5032, 5036

    CNOP 0,4
charcounter:    dc.w 0      ; 16bit wide ==> max 2^16 chars in scrolly
scrollcounter:  dc.w -1     ; start = -1

coppercolors:   dc.w $001,$002,$003,$004,$005,$006,$007,$008,$00a,$00b,$00c,$00e,$00f,$00e,$00c,$00b,$00a,$008,$007,$006,$005,$004,$003,$002,$001

    Section ChipRAM,Data_c

; bitplanes aligned to 32-bit
    CNOP 0,4
bpl0:   dc.l 0              ; pointer to actual bitplane 0 (double buffering bpl0a / bpl0b)
bpl1:   dc.l 0              ; pointer to actual bitplane 1 (double buffering bpl1a / bpl1b)
bpl0x:  dc.l 0              ; pointer to buffered bitplane 0
bpl1x:  dc.l 0              ; pointer to buffered bitplane 1 
bpl0a:  blk.b 352/8*200,0
bpl1a:  blk.b 352/8*200,0
bpl0b:  blk.b 352/8*200,0
bpl1b:  blk.b 352/8*200,0

; datalists aligned to 32-bit
    CNOP 0,4
copper1:    
            dc.l $ffffffe   ; CHIPMEM!
            blk.l 2047,0    ; CHIPMEM!
    CNOP 0,4
copper2:    
            dc.l $ffffffe   ; CHIPMEM!
            blk.l 2047,0    ; CHIPMEM!

    CNOP 0,4
font:   incbin "font.raw"   ; 10x5 chars each 32px wide, 25px high (start: ascii 32)
