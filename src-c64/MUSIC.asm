;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;
;; C64 port - music and sound effects on the SID. The notes, tempo and rhythm are the original's (the data is
;; made from the BBC source by tools/make_music.py); the sounds are SID instruments chosen for this port.
;;
;; The engine runs from the raster interrupt (SPRMUX.asm calls music_frame once a frame, at line SPR_MUSIC_LINE), so
;; the tempo no longer depends on how long the game loop takes. The original advances its music on the vertical-sync
;; event, 50 ticks a second; one tick is a frame on a PAL machine and 5 frames in every 6 on NTSC (an 8.8 fraction
;; in m_acc). Three music voices = the three SID voices. A sound effect takes voice 3 over for its length (the music
;; on that voice carries on silently underneath and rejoins at its next note).
;;
;; API (called from INIT.asm):
;;   music_start    A = tune (MUS_*)   start a tune on all three voices (replaces whatever plays)
;;   music_stop                        silence the music
;;   music_busy                        Z clear while any voice still has notes to play
;;   sfx_play       A = effect (SFX_*) not in the demo, as in the original
;; The code and data live in the free part of VIC bank 1 (galaforce1-c64.cfg: MUSIC), not in the main memory.

.segment "ZP2": zeropage
m_ptr:     .res 6            ; note stream pointers, one word per voice (index 0, 2, 4)
fx_ptr:    .res 2

.segment "SPRVAR"
m_cnt:     .res 6            ; ticks until the voice's next note byte
m_gate:    .res 6            ; ticks until its gate goes off (0 = already off)
m_active:  .res 6
m_inst:    .res 6            ; instrument (offset into mus_inst)
m_wave:    .res 6            ; waveform of the note sounding, with its gate bit
m_speed:   .res 4            ; ticks per duration class
m_acc:     .res 1
m_pal:     .res 1
m_vol:     .res 1
m_note:    .res 1
m_t2:      .res 1
t_flo:     .res 1
t_fhi:     .res 1
t_pwlo:    .res 1
t_pwhi:    .res 1
t_ad:      .res 1
t_sr:      .res 1
fx_active: .res 1
sound_off: .res 1            ; 1 = the S key has switched the sound off
fx_frames: .res 1
fx_wave:   .res 1
fx_flo:    .res 1
fx_fhi:    .res 1
fx_dlo:    .res 1
fx_dhi:    .res 1

.segment "MUSDATA"
.include "src-c64/gen/music.inc"
mus_voff:  .byte 0,0,7,0,14  ; SID register offset of voice 0, 1, 2 for X = 0, 2, 4

.segment "MUSCODE"

NTSC_TICK_RATE = 213         ; 50/60 of a tick per frame, in 1/256ths

; music_init: once, from spr_init (interrupts off). Clears the SID, finds out whether this is a PAL machine (312
; raster lines) or an NTSC one (262/263) and, for PAL, swaps in the PAL pitch table.
music_init:
    ldx #$18
    lda #0
mi_clear:
    sta $D400,x
    dex
    bpl mi_clear
    lda #15
    sta $D418
    sta m_vol
    lda #0
    sta m_acc
    sta m_pal
    sta m_tmp_max
    sta fx_active
    sta sound_off
    ldx #5
mi_state:
    sta m_active,x
    sta m_gate,x
    sta m_wave,x
    dex
    bpl mi_state
mi_wait:
    lda $D011               ; wait for the raster to pass line 255, then watch it up to the end of the frame
    bpl mi_wait
mi_scan:
    lda $D012
    cmp m_tmp_max
    bcc mi_low
    sta m_tmp_max
mi_low:
    lda $D011
    bmi mi_scan
    lda m_tmp_max
    cmp #24                 ; the last line is 311 (PAL: 55 past 256) or 262 (NTSC: 6)
    bcc mi_done
    lda #1
    sta m_pal
    ldx #127
mi_pal:
    lda mus_fpal_lo,x
    sta mus_fntsc_lo,x
    dex
    bpl mi_pal
mi_done:
    rts
m_tmp_max: .byte 0

; music_frame: once a frame, from the raster interrupt.
music_frame:
    jsr fx_frame
    lda game_paused         ; the pause key silences everything
    beq mf_run
    lda m_vol
    beq mf_rts
    lda #0
    sta m_vol
    sta $D418
mf_rts:
    rts
mf_run:
    lda m_vol
    bne mf_vol_ok
    lda #15
    sta m_vol
    sta $D418
mf_vol_ok:
    lda m_pal
    bne mf_tick
    lda m_acc
    clc
    adc #NTSC_TICK_RATE
    sta m_acc
    bcc mf_rts              ; no tick this frame (1 in 6)
mf_tick:
    ldx #4
mf_loop:
    jsr music_chan
    dex
    dex
    bpl mf_loop
    rts

; music_chan: one tick for voice X (0, 2 or 4).
music_chan:
    lda m_active,x
    beq mc_rts
    lda m_gate,x
    beq mc_nogate
    dec m_gate,x
    bne mc_nogate
    jsr gate_off
mc_nogate:
    dec m_cnt,x
    beq mc_next
mc_rts:
    rts
mc_next:
    lda (m_ptr,x)
    inc m_ptr,x
    bne mc_got
    inc m_ptr+1,x
mc_got:
    sta m_note
    cmp #0
    bne mc_note
    jmp mc_end              ; a 0 byte ends the stream
mc_note:
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a
    lsr a                   ; duration class 0-3
    tay
    lda m_speed,y
    sta m_cnt,x
    lda m_note
    and #63
    cmp #63
    beq mc_rts              ; a rest
    sta m_note

; a note: pitch in m_note, its length (ticks) in m_cnt,x. The gate stays on for the length less a quarter (at least
; one tick), so repeated notes are separate.
    lda m_cnt,x
    lsr a
    lsr a
    bne mn_shave
    lda #1
mn_shave:
    sta m_t2
    lda m_cnt,x
    sec
    sbc m_t2
    bne mn_gate
    lda #1
mn_gate:
    sta m_gate,x
    ldy m_note
    lda mus_fntsc_lo,y
    sta t_flo
    lda mus_fntsc_hi,y
    sta t_fhi
    ldy m_inst,x
    lda mus_inst,y
    sta m_wave,x
    lda mus_inst+1,y
    sta t_pwlo
    lda mus_inst+2,y
    sta t_pwhi
    lda m_cnt,x
    cmp #MUS_LONG_TICKS
    bcs mn_long
    lda mus_inst+3,y
    sta t_ad
    lda mus_inst+4,y
    sta t_sr
    jmp mn_write
mn_long:
    lda mus_inst+5,y
    sta t_ad
    lda mus_inst+6,y
    sta t_sr
mn_write:
    cpx #4
    bne mn_go
    lda fx_active           ; voice 3 belongs to a sound effect for now
    bne mn_rts
mn_go:
    ldy mus_voff,x
    lda #0
    sta $D404,y             ; gate off, so the envelope restarts
    lda t_flo
    sta $D400,y
    lda t_fhi
    sta $D401,y
    lda t_pwlo
    sta $D402,y
    lda t_pwhi
    sta $D403,y
    lda t_ad
    sta $D405,y
    lda t_sr
    sta $D406,y
    lda m_wave,x
    sta $D404,y             ; waveform + gate on
mn_rts:
    rts
mc_end:
    lda #0
    sta m_active,x
    ; falls into gate_off

; gate_off: release voice X.
gate_off:
    cpx #4
    bne go_ok
    lda fx_active
    bne go_rts
go_ok:
    ldy mus_voff,x
    lda m_wave,x
    and #$FE
    sta $D404,y
go_rts:
    rts

; music_start: A = tune.
music_start:
    ldx sound_off           ; (sound off: nothing starts, so nothing is ever left playing)
    beq ms_go
    rts
ms_go:
    php
    sei
    asl a
    asl a
    asl a
    asl a
    tay
    ldx #0
ms_chan:
    lda mus_tunes,y
    sta m_ptr,x
    lda mus_tunes+1,y
    sta m_ptr+1,x
    lda #1
    sta m_cnt,x
    lda #0
    sta m_gate,x
    lda #1
    sta m_active,x
    iny
    iny
    inx
    inx
    cpx #6
    bne ms_chan
    ldx #0
ms_speed:
    lda mus_tunes,y
    sta m_speed,x
    iny
    inx
    cpx #4
    bne ms_speed
    lda mus_tunes,y
    sta m_inst+0
    lda mus_tunes+1,y
    sta m_inst+2
    lda mus_tunes+2,y
    sta m_inst+4
    ldx #4
ms_off:
    jsr gate_off
    dex
    dex
    bpl ms_off
    plp
    rts

; music_stop
music_stop:
    php
    sei
    ldx #4
mst_loop:
    lda #0
    sta m_active,x
    jsr gate_off
    dex
    dex
    bpl mst_loop
    plp
    rts

; music_busy: Z set when no voice has anything left to play.
music_busy:
    lda m_active+0
    ora m_active+2
    ora m_active+4
    rts

; sound_toggle: the S key (ROUT1.asm's sound_on_off). Off silences everything at once; on takes effect with the
; next tune or effect.
sound_toggle:
    lda sound_off
    eor #1
    sta sound_off
    beq stg_rts
    jsr music_stop
    php
    sei
    lda #0
    sta fx_active
    sta $D412
    plp
stg_rts:
    rts

; ---- sound effects, on voice 3 ----------------------------------------------------------------------------------------
; An effect is a header (waveform, pulse width, AD, SR) and segments (frames, start frequency, change per frame) that
; sweep the pitch; fx_frame runs every frame.
sfx_play:
    ldy demo_flag
    bne sp_rts              ; the demo is silent but for its music, as in the original
    ldy sound_off
    bne sp_rts
    tax
    php
    sei
    lda mus_fx_lo,x
    sta fx_ptr
    lda mus_fx_hi,x
    sta fx_ptr+1
    ldy #0
    lda (fx_ptr),y
    sta fx_wave
    iny
    lda (fx_ptr),y
    sta $D410
    iny
    lda (fx_ptr),y
    sta $D411
    iny
    lda (fx_ptr),y
    sta $D413
    iny
    lda (fx_ptr),y
    sta $D414
    lda fx_ptr
    clc
    adc #5
    sta fx_ptr
    bcc sp_seg
    inc fx_ptr+1
sp_seg:
    jsr fx_load_seg
    lda #1
    sta fx_active
    lda #0
    sta $D412
    jsr fx_write_freq
    lda fx_wave
    sta $D412
    plp
sp_rts:
    rts

; fx_load_seg: the next segment (frames, f lo, f hi, d lo, d hi); fx_frames = 0 when there is none.
fx_load_seg:
    ldy #0
    lda (fx_ptr),y
    sta fx_frames
    beq fls_rts
    iny
    lda (fx_ptr),y
    sta fx_flo
    iny
    lda (fx_ptr),y
    sta fx_fhi
    iny
    lda (fx_ptr),y
    sta fx_dlo
    iny
    lda (fx_ptr),y
    sta fx_dhi
    lda fx_ptr
    clc
    adc #5
    sta fx_ptr
    bcc fls_rts
    inc fx_ptr+1
fls_rts:
    rts

fx_write_freq:
    lda fx_flo
    sta $D40E
    lda fx_fhi
    sta $D40F
    rts

fx_frame:
    lda fx_active
    beq ff_rts
    lda fx_flo
    clc
    adc fx_dlo
    sta fx_flo
    lda fx_fhi
    adc fx_dhi
    sta fx_fhi
    jsr fx_write_freq
    dec fx_frames
    bne ff_rts
    jsr fx_load_seg
    lda fx_frames
    bne ff_rts
    lda fx_wave
    and #$FE
    sta $D412
    lda #0
    sta fx_active
ff_rts:
    rts
