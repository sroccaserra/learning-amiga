; Copperbarscroller-1

DMACONR		EQU		$dff002
ADKCONR		EQU		$dff010
INTENAR		EQU		$dff01c
INTREQR		EQU		$dff01e

DMACON		EQU		$dff096
ADKCON		EQU		$dff09e
INTENA		EQU		$dff09a
INTREQ		EQU		$dff09c

	incdir "windows:amigavikke/"

; Optimizations could easily be made to the small/tight loops in the code by using incremental addressing (An)+ or decremental addressing -(An) and REPT <n> / ERPT

init:
; store hardware registers, store view- and copperaddresses, load blank view, wait 2x for top of frame, own blitter, wait for blitter AND finally forbid multitasking!
; all this just to be able to exit gracely

	; store data in hardwareregisters ORed with $8000 (bit 15 is a write-set bit when values are written back into the system)
	move.w	DMACONR,d0
	or.w #$8000,d0
	move.w d0,olddmareq
	move.w	INTENAR,d0
	or.w #$8000,d0
	move.w d0,oldintena
	move.w	INTREQR,d0
	or.w #$8000,d0
	move.w d0,oldintreq
	move.w	ADKCONR,d0
	or.w #$8000,d0
	move.w d0,oldadkcon

	move.l	$4,a6 				; execBase ==> a6
	move.l	#gfxname,a1 		; pointer to gfxname ==> a1 : used in openLibrary
	moveq	#0,d0 				; d0 = 0 any version of graphics.library will do
	jsr	-552(a6)				; d0 = openLibrary(a1,d0)
	move.l	d0,gfxbase 			; store the returned pointer ==> gfxbase
	move.l 	d0,a6 				; d0 ==> a6 : a6 used as addressing base below
	move.l 	34(a6),oldview 		; store old Viewport
	move.l 	38(a6),oldcopper 	; store old Copperlist

	move.l #0,a1
	jsr -222(a6)	; LoadView
	jsr -270(a6)	; WaitTOF
	jsr -270(a6)	; WaitTOF
	jsr -456(a6)	; OwnBlitter
	jsr -228(a6)	; WaitBlit
	move.l	$4,a6
	jsr -132(a6)	; Forbid

; end exit gracely preparations!

	; clear Bitplanes from garbage - very slow routine! should be done with the Blitter, or unrolled loop
	move.w #352/8*200/4,d0 	; d0 is a counter for number of longwords to get cleared
	move.l #bpl0,a0 	; bpl0 => a0
	move.l #bpl1,a1 	; bpl1 => a1
	move.l #bpl2,a2 	; bpl2 => a2
	screen_clear:
		move.l #0,(a0)+	; #0 => (a0), and increment a0 to next longword (a0=a0+4)
		move.l #0,(a1)+	; #0 => (a1), and increment a1 to next longword (a1=a1+4)
		move.l #0,(a2)+	; #0 => (a2), and increment a1 to next longword (a2=a2+4)
		subq.w #1,d0
		bne screen_clear
		
	; copy bitmap to bitplanes
	move.w #352/8*200/4,d0
	move.l #bpl0,a0 	; bpl0 => a0
	move.l #bpl1,a1 	; bpl1 => a1
	move.l #bpl2,a2 	; bpl1 => a2
	move.l #img_av,a6
;	add.l #2,a6
	copy_img:
		move.l 352/8*200*2(a6),(a2)+	; bpl2
		move.l 352/8*200*1(a6),(a1)+	; bpl1
		move.l (a6)+,(a0)+				; bpl0
		subq.w #1,d0
		bne copy_img
		

; setup displayhardware to show a 320x200px 3 bitplanes playfield, with zero horizontal scroll and 4 modulos
	move.w	#$3200,$dff100				; 3 bitplane lowres
	move.w	#$0000,$dff102				; horizontal scroll 0
	move.w	#$0002,$dff108				; odd modulo 4
	move.w	#$0002,$dff10a				; even modulo 4
	move.w	#$2c81,$dff08e				; DIWSTRT - topleft corner (2c81)
	move.w	#$f4d1,$dff090				; DIVSTOP - bottomright corner (f4d1)
	move.w	#$0030,$dff092				; DDFSTRT - max overscan $0018 ; standard 0038 & 00d0
	move.w	#$00d0,$dff094				; DDFSTOP - max overscan $00d8 ; max overscan: 368x283px in PAL
	move.w 	#%1000010111000000,DMACON	; DMA set ON
	move.w 	#%0000000000111111,DMACON	; DMA set OFF
	move.w 	#%1100000000000000,INTENA	; IRQ set ON
	move.w 	#%0011111111111111,INTENA	; IRQ set OFF


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
; 32px high copperbars for scrolling (p=32*pi ==> p~100 ==> image 100px high)
;
; *********************************************************


	move.l #$2c+$50,d2
	jsr make_Copper_scrolly




	; end of copperlist (copperlist ALWAYS ends with WAIT $fffffffe)
	move.l #$fffffffe,(a6)+ 	; end copperlist

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
	move.w #$7fff,DMACON 		; set bits[0,14] = 0 (bit15 is a set/clear bit)
	move.w	olddmareq,DMACON 	; and set bits[0,14] as they were at init
	move.w #$7fff,INTENA 		; set bits[0,14] = 0 (bit15 is a set/clear bit)
	move.w	oldintena,INTENA 	; and set bits[0,14] as they were at init
	move.w #$7fff,INTREQ 		; set bits[0,14] = 0 (bit15 is a set/clear bit)
	move.w	oldintreq,INTREQ 	; and set bits[0,14] as they were at init
	move.w #$7fff,ADKCON 		; set bits[0,14] = 0 (bit15 is a set/clear bit)
	move.w	oldadkcon,ADKCON 	; and set bits[0,14] as they were at init

	move.l	oldcopper,$dff080 	; load old Copperlist
	; graphics.library calls
	move.l 	gfxbase,a6 	; gfxBase ==> a6
	move.l 	oldview,a1 	; oldView ==> a1 (used in LoadView)
	jsr -222(a6)		; LoadView : load back the view at start of program
	jsr -270(a6)		; WaitTOF : Wait for Top Of Frame to get everything synced up
	jsr -270(a6)		; WaitTOF : (2 times for interlaced screens)
	jsr -228(a6)		; WaitBlit : wait for Blitter to finish running task (if any)
	jsr -462(a6)		; DisownBlitter : release Blitter to system
	; exec.library calls
	move.l	$4,a6 		; execBase ==> a6
	move.l	gfxbase,a1 	; gfxBase ==> a1 (used in closeLibrary)
	jsr -414(a6) 		; closeLibrary : close graphics.library
	jsr -138(a6)		; Permit multitasking

	; end program
	rts

; subroutines

make_Copper_scrolly:

	move.l #c0,a0 				; pointer to colortables ==> a0
	move.l #hshift,a4
	move.l #mshift,a5
	move.l #$07<<16+$fffe,d1 	; this is optimized code compaired to earlier tutorials
								; $07<<16 = $00070000,
								; and then +$fffe gives $0007fffe
	lsl.l #8,d2 				; d2 = d2 * 2^24
	lsl.l #8,d2
	lsl.l #8,d2
	add.l d2,d1 				; add d2 to d1 ==> first time: d1 = $2c07fffe, which is:
								; Copper WAIT <$2c07>,<$fffe>: V:$2c & H:$07 & mask:$fffe

	moveq #0,d0 				; d0 = 0
	move.w cbar_img_line1,d0 	; startingline index ==> d0
	add.w #44,d0 				; d0 = d0 + 44 (352px/8 = 44 bytes)
	cmp.w #200*44,d0 			; compare if larger than the height of the image
	bcs .10
	sub.w #200*44,d0 			; if it is, then subract the overgoing part from it
	.10:
	move.w d0,cbar_img_line1 	; store new startingline index for next frame

	moveq #64,d7
	loop_cbar1:
		move.l d1,(a6)+ 		; copper WAIT
		move.w #$0180,(a6)+ 	; color0-
		move.w 0*128(a0),(a6)+ 	;        value
		move.w #$0102,(a6)+		; h-shift-
		move.w (a4)+,(a6)+ 		;         value

		moveq #0,d3
		move.w (a5)+,d3
		; bitplane 0
		move.l #bpl0,d2
		add.l d0,d2 		; add startingline index to address
		add.l d3,d2 		; add 16-bit Hshift
		move.w #$00e2,(a6)+	; LO-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e2
		swap d2
		move.w #$00e0,(a6)+	; HI-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e0
		
		; bitplane 1
		move.l #bpl1,d2
		add.l d0,d2 		; add startingline index to address
		add.l d3,d2 		; add 16-bit Hshift
		move.w #$00e6,(a6)+	; LO-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e6
		swap d2
		move.w #$00e4,(a6)+	; HI-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e4
		
		; bitplane 2
		move.l #bpl2,d2
		add.l d0,d2 		; add startingline index to address
		add.l d3,d2 		; add 16-bit Hshift
		move.w #$00ea,(a6)+	; LO-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e6
		swap d2
		move.w #$00e8,(a6)+	; HI-bits of start of bitplane
		move.w d2,(a6)+		; go into $dff0e4

		move.w #$0182,(a6)+ 	; color1-
		move.w 1*128(a0),(a6)+ 	;        value
		move.w #$0184,(a6)+ 	; color2-
		move.w 2*128(a0),(a6)+ 	;        value
		move.w #$0186,(a6)+ 	; color3-
		move.w 3*128(a0),(a6)+ 	;        value
		move.w #$0188,(a6)+ 	; color4-
		move.w 4*128(a0),(a6)+ 	;        value
		move.w #$018a,(a6)+ 	; color5-
		move.w 5*128(a0),(a6)+ 	;        value
		move.w #$018c,(a6)+ 	; color6-
		move.w 6*128(a0),(a6)+ 	;        value
		move.w #$018e,(a6)+ 	; color7-
		move.w 7*128(a0),(a6)+ 	;        value
		add.l #2,a0

		
		add.l #1<<24,d1 	; here the optimization continues,
							; we know that the verticalvalues are in bits[24,31],
							; so we add 1*2^24 to get to the next line

		add.w #44,d0 				; d0 = d0 + 44 (352px/8 = 44 bytes)
		cmp.w #200*44,d0 			; compare if larger than the height of the image
		bcs .20
		sub.w #200*44,d0 			; if it is, then subract the overgoing part from it
		.20:

		subq #1,d7
		bne loop_cbar1

	rts 					; end subroutine and get back to main code



; *******************************************************************************
; *******************************************************************************
; DATA
; *******************************************************************************
; *******************************************************************************


; storage for 32-bit addresses and data
	CNOP 0,4
oldview:	dc.l 0
oldcopper:	dc.l 0
gfxbase:	dc.l 0
frame:		dc.l 0
copper:		dc.l 0

; storage for 16-bit data
	CNOP 0,4
olddmareq:	dc.w 0
oldintreq:	dc.w 0
oldintena:	dc.w 0
oldadkcon:	dc.w 0

	CNOP 0,4
; storage for 8-bit data and text
gfxname:		dc.b 'graphics.library',0
author:			dc.b 'AmigaVikke',0

	CNOP 0,4
c0:	dc.w $000,$100,$101,$201,$202,$302,$303,$403,$404,$504,$505,$605,$606,$706,$707,$807,$808,$908,$909,$a09,$a0a,$b0a,$b0b,$c0b,$c0b,$c0c,$d0c,$d0d,$e0d,$e0e,$f0e,$f0f,$f0f,$f0e,$e0e,$e0d,$d0d,$d0c,$c0c,$c0b,$c0b,$b0b,$b0a,$a0a,$a09,$909,$908,$808,$807,$707,$706,$606,$605,$505,$504,$404,$403,$303,$302,$202,$201,$101,$100,$000
c1:	dc.w $000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$111,$111,$111,$111,$222,$222,$222,$333,$333,$222,$222,$222,$111,$111,$111,$111,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000,$000
c2: dc.w $000,$000,$100,$100,$200,$200,$300,$300,$400,$400,$500,$500,$600,$600,$700,$700,$800,$800,$900,$900,$A00,$A00,$B00,$B00,$C00,$C00,$D00,$D00,$E00,$E00,$F00,$F00,$F00,$F00,$E00,$E00,$D00,$D00,$C00,$C00,$B00,$B00,$A00,$A00,$900,$900,$800,$800,$700,$700,$600,$600,$500,$500,$400,$400,$300,$300,$200,$200,$100,$100,$000,$000
c3: dc.w $000,$000,$010,$010,$020,$020,$030,$030,$040,$040,$050,$050,$060,$060,$070,$070,$080,$080,$090,$090,$0A0,$0A0,$0B0,$0B0,$0C0,$0C0,$0D0,$0D0,$0E0,$0E0,$0F0,$0F0,$0F0,$0F0,$0E0,$0E0,$0D0,$0D0,$0C0,$0C0,$0B0,$0B0,$0A0,$0A0,$090,$090,$080,$080,$070,$070,$060,$060,$050,$050,$040,$040,$030,$030,$020,$020,$010,$010,$000,$000
c4: dc.w $000,$000,$001,$001,$002,$002,$003,$003,$004,$004,$005,$005,$006,$006,$007,$007,$008,$008,$009,$009,$00A,$00A,$00B,$00B,$00C,$00C,$00D,$00D,$00E,$00E,$00F,$00F,$00F,$00F,$00E,$00E,$00D,$00D,$00C,$00C,$00B,$00B,$00A,$00A,$009,$009,$008,$008,$007,$007,$006,$006,$005,$005,$004,$004,$003,$003,$002,$002,$001,$001,$000,$000
c5: dc.w $000,$000,$110,$110,$220,$220,$330,$330,$440,$440,$550,$550,$660,$660,$770,$770,$880,$880,$990,$990,$AA0,$AA0,$BB0,$BB0,$CC0,$CC0,$DD0,$DD0,$EE0,$EE0,$FF0,$FF0,$FF0,$FF0,$EE0,$EE0,$DD0,$DD0,$CC0,$CC0,$BB0,$BB0,$AA0,$AA0,$990,$990,$880,$880,$770,$770,$660,$660,$550,$550,$440,$440,$330,$330,$220,$220,$110,$110,$000,$000
c6: dc.w $000,$000,$111,$111,$222,$222,$333,$333,$444,$444,$555,$555,$666,$666,$777,$777,$888,$888,$999,$999,$AAA,$AAA,$BBB,$BBB,$CCC,$CCC,$DDD,$DDD,$EEE,$EEE,$FFF,$FFF,$FFF,$FFF,$EEE,$EEE,$DDD,$DDD,$CCC,$CCC,$BBB,$BBB,$AAA,$AAA,$999,$999,$888,$888,$777,$777,$666,$666,$555,$555,$444,$444,$333,$333,$222,$222,$111,$111,$000,$000
c7: dc.w $000,$000,$011,$011,$022,$022,$033,$033,$044,$044,$055,$055,$066,$066,$077,$077,$088,$088,$099,$099,$0AA,$0AA,$0BB,$0BB,$0CC,$0CC,$0DD,$0DD,$0EE,$0EE,$0FF,$0FF,$0FF,$0FF,$0EE,$0EE,$0DD,$0DD,$0CC,$0CC,$0BB,$0BB,$0AA,$0AA,$099,$099,$088,$088,$077,$077,$066,$066,$055,$055,$044,$044,$033,$033,$022,$022,$011,$011,$000,$000


cbar_img_line1:	dc.w 0

shift1:		dc.w $00,$11,$33,$44,$66,$77,$99,$AA,$BB,$CC,$DD,$EE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$EE,$DD,$CC,$BB,$AA,$99,$77,$66,$44,$33,$11,$00


sin255_60:	dc.b 30,31,31,32,33,34,34,35,36,37,37,38,39,39,40,41,42,42,43,44,44,45,45,46,47,47,48,49,49,50,50,51,51,52,52,53,53,54,54,55,55,55,56,56,57,57,57,57,58,58,58,59,59,59,59,59,59,60,60,60,60,60,60,60,60,60,60,60,60,60,60,60,59,59,59,59,59,58,58,58,58,57,57,57,56,56,56,55,55,54,54,53,53,53,52,52,51,50,50,49,49,48,48,47,46,46,45,45,44,43,43,42,41,40,40,39,38,38,37,36,36,35,34,33,33,32,31,30,30,29,28,27,27,26,25,24,24,23,22,22,21,20,20,19,18,17,17,16,15,15,14,14,13,12,12,11,11,10,10,9,8,8,7,7,7,6,6,5,5,4,4,4,3,3,3,2,2,2,2,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,1,2,2,2,3,3,3,3,4,4,5,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,13,13,14,15,15,16,16,17,18,18,19,20,21,21,22,23,23,24,25,26,26,27,28,29,29,30
	CNOP 0,4
cos255:		dc.b 255,255,255,255,254,254,254,253,253,252,251,250,249,249,248,246,245,244,243,241,240,238,237,235,233,232,230,228,226,224,222,220,218,215,213,211,208,206,203,201,198,196,193,190,187,185,182,179,176,173,170,167,164,161,158,155,152,149,146,143,140,137,133,130,127,124,121,118,115,112,109,105,102,99,96,93,90,87,84,81,78,76,73,70,67,65,62,59,57,54,51,49,47,44,42,40,37,35,33,31,29,27,25,23,22,20,18,17,15,14,13,11,10,9,8,7,6,5,4,4,3,3,2,2,1,1,1,1,1,1,1,1,2,2,3,3,4,4,5,6,7,8,9,10,11,13,14,15,17,18,20,22,23,25,27,29,31,33,35,37,40,42,44,47,49,51,54,57,59,62,64,67,70,73,76,78,81,84,87,90,93,96,99,102,105,109,112,115,118,121,124,127,130,133,137,140,143,146,149,152,155,158,161,164,167,170,173,176,179,182,185,187,190,193,196,198,201,203,206,208,211,213,215,218,220,222,224,226,228,230,232,233,235,237,238,240,241,243,244,245,246,248,249,249,250,251,252,253,253,254,254,254,255,255,255,255
	CNOP 0,4

hshift:	dc.w $00,$88,$BB,$DD,$FF,$11,$22,$44,$55,$66,$77,$88,$88,$99,$AA,$BB,$BB,$CC,$CC,$DD,$DD,$DD,$EE,$EE,$EE,$EE,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$FF,$EE,$EE,$EE,$EE,$DD,$DD,$DD,$CC,$CC,$BB,$BB,$AA,$99,$88,$88,$77,$66,$55,$44,$22,$11,$FF,$DD,$BB,$88,$00
;mshift:	dc.w 2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,2,2
mshift:	dc.w 4,4,4,4,4,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,4,4,4,4,4
;mshift:	dc.w 6,6,6,6,6,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,6,6,6,6,6


	Section ChipRAM,Data_c

; bitplanes aligned to 32-bit
	CNOP 0,4
bpl0:	blk.b 352/8*200,0
bpl1:	blk.b 352/8*200,0
bpl2:	blk.b 352/8*200,0

; datalists aligned to 32-bit
	CNOP 0,4
copper1:	
			dc.l $ffffffe 	; CHIPMEM!
			blk.l 2047,0 	; CHIPMEM!
	CNOP 0,4
copper2:	
			dc.l $ffffffe 	; CHIPMEM!
			blk.l 2047,0 	; CHIPMEM!

	CNOP 0,4
img_av:	incbin "amigavikke-flowers.raw"