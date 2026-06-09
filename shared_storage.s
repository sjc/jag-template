;
; shared_storage.s
; BSS used by both ROM loader and in-RAM code
;

        .include "bootconst.inc"

LISTSIZE = 5

        .bss
        .even
_VBI::          .ds.w   (VBISIZE/2)     ; the VBI code will be copied here
        .dphrase
_vidmem::       .ds.w   320*200
        .dphrase
listbuf::       .ds.l   LISTSIZE*2          ; Object List
bmpupdate::     .ds.l   2               ; One Phrase of Bitmap for Refresh

_VID_tick::     .ds.w   1
_VID_pal::      .ds.w   1

_VID_width::    .ds.w   1
_VID_height::   .ds.w   1

_VID_hdb::      .ds.w   1
_VID_hde::      .ds.w   1
_VID_vdb::      .ds.w   1
_VID_vde::      .ds.w   1

_bgcol::        .ds.w   1 ; temp
