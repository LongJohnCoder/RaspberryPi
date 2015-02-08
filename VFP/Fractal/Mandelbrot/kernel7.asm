; Raspberry Pi 2 'Bare Metal' Mandelbrot Fractal Demo by krom (Peter Lemon):
; 1. Turn On L1 Cache
; 2. Turn On Vector Floating Point Unit
; 3. Setup Frame Buffer
; 4. Plot Fractal Using Double-Precision

format binary as 'img'
include 'LIB\FASMARM.INC'
include 'LIB\R_PI2.INC'

; Setup Frame Buffer
SCREEN_X       = 640
SCREEN_Y       = 480
BITS_PER_PIXEL = 32

; Setup VFP
VFPEnable = $40000000
VFPSingle = $300000
VFPDouble = $C00000

org $8000

; Enable Vector Floating Point Calculations
mov r0,VFPSingle + VFPDouble ; Enable Single & Double Precision
mcr p15,0,r0,c1,c0,2 ; Access Control Register = R0
mov r0,VFPEnable ; Enable VFP
vmsr fpexc,r0 ; FPEXC = R0

FB_Init:
  imm32 r0,FB_STRUCT + MAIL_TAGS
  imm32 r1,PERIPHERAL_BASE + MAIL_BASE + MAIL_WRITE + MAIL_TAGS
  str r0,[r1] ; Mail Box Write

  ldr r0,[FB_POINTER] ; R0 = Frame Buffer Pointer
  cmp r0,0 ; Compare Frame Buffer Pointer To Zero
  beq FB_Init ; IF Zero Re-Initialize Frame Buffer

ldr r1,[LAST_PIXEL]
add r0,r1 ; R0 = Frame Buffer Pointer Last Pixel

mov r1,SCREEN_X ; Load Double Screen X
fmsr s31,r1
fsitod d0,s31 ; D0 = X%
fcpyd d2,d0   ; D2 = SX

mov r1,SCREEN_Y ; Load Double Screen Y
fmsr s31,r1
fsitod d1,s31 ; D1 = Y%
fcpyd d3,d1   ; D3 = SY

fldd d4,[XMAX] ; D4 = XMax
fldd d5,[YMAX] ; D5 = YMax
fldd d6,[XMIN] ; D6 = XMin
fldd d7,[YMIN] ; D7 = YMin
fldd d8,[RMAX] ; D8 = RMax
fldd d9,[ONE]  ; D9 = 1.0

ldr r12,[COL_MUL] ; R12 = Multiply Colour

LoopY:
  fcpyd d0,d2 ; D0 = X%
  LoopX:
    fsubd d10,d4,d6 ; CX = XMin + ((X% * (XMax - XMin)) / SX)
    fmuld d10,d0
    fdivd d10,d2
    faddd d10,d6 ; D10 = CX

    fsubd d11,d5,d7 ; CY = YMin + ((Y% * (YMax - YMin)) / SY)
    fmuld d11,d1
    fdivd d11,d3
    faddd d11,d7 ; D11 = CY

    mov r1,192 ; R1 = IT (Iterations)
    fsubd d12,d12 ; D12 = ZX
    fsubd d13,d13 ; D13 = ZY

    Iterate:
      fmuld d14,d13,d13 ; XN = ((ZX * ZX) - (ZY * ZY)) + CX
      fmscd d14,d12,d12
      faddd d14,d10 ; D14 = XN

      fmuld d15,d12,d13 ; YN = (2 * ZX * ZY) + CY
      faddd d15,d15
      faddd d15,d11 ; D15 = YN

      fcpyd d12,d14 ; Copy XN & YN To ZX & ZY For Next Iteration
      fcpyd d13,d15

      fmuld d14,d12,d12 ; R = (XN * XN) + (YN * YN)
      fmacd d14,d13,d13 ; D14 = R

      fcmpd d14,d8 ; IF (R > 4) Plot
      fmstat
      bgt Plot

      subs r1,1 ; IT -= 1
      bne Iterate ; IF (IT != 0) Iterate

    Plot:
      mul r1,r12 ; R1 = Pixel Colour
      orr r1,$FF000000 ; Force Alpha To $FF
      str r1,[r0],-4 ; Store Pixel Colour To Frame Buffer

      fsubd d0,d9 ; Decrement X%
      fcmpzd d0
      fmstat
      bne LoopX ; IF (X% != 0) LoopX

      fsubd d1,d9 ; Decrement Y%
      fcmpzd d1
      fmstat
      bne LoopY ; IF (Y% != 0) LoopY

Loop:
  b Loop

XMAX: dd 1.0
YMAX: dd 1.0
XMIN: dd -2.0
YMIN: dd -1.0
RMAX: dd 4.0
ONE:  dd 1.0

COL_MUL: dw $231AF9 ; Multiply Colour
LAST_PIXEL: dw (SCREEN_X * SCREEN_Y * (BITS_PER_PIXEL / 8)) - (BITS_PER_PIXEL / 8)

align 16
FB_STRUCT: ; Mailbox Property Interface Buffer Structure
  dw FB_STRUCT_END - FB_STRUCT ; Buffer Size In Bytes (Including The Header Values, The End Tag And Padding)
  dw $00000000 ; Buffer Request/Response Code
	       ; Request Codes: $00000000 Process Request Response Codes: $80000000 Request Successful, $80000001 Partial Response
; Sequence Of Concatenated Tags
  dw Set_Physical_Display ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Virtual_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw SCREEN_X ; Value Buffer
  dw SCREEN_Y ; Value Buffer

  dw Set_Depth ; Tag Identifier
  dw $00000004 ; Value Buffer Size In Bytes
  dw $00000004 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
  dw BITS_PER_PIXEL ; Value Buffer

  dw Set_Virtual_Offset ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_OFFSET_X:
  dw 0 ; Value Buffer
FB_OFFSET_Y:
  dw 0 ; Value Buffer

  dw Allocate_Buffer ; Tag Identifier
  dw $00000008 ; Value Buffer Size In Bytes
  dw $00000008 ; 1 bit (MSB) Request/Response Indicator (0=Request, 1=Response), 31 bits (LSB) Value Length In Bytes
FB_POINTER:
  dw 0 ; Value Buffer
  dw 0 ; Value Buffer

dw $00000000 ; $0 (End Tag)
FB_STRUCT_END: