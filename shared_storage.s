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
        .phrase
_OLPstore::     .ds.l   32              ; Master Object List Storage
        .long
_packed_olist:: .ds.l    16             ; overkill for our example here

_OList::        .ds.l   1               ; pointer to current object list
                                        ; which will be copied over the top of OLPStore
_VID_tick::     .ds.w   1
_VID_pal::      .ds.w   1

_VID_width::    .ds.w   1
_VID_height::   .ds.w   1

_VID_hdb::      .ds.w   1
_VID_hde::      .ds.w   1
_VID_vdb::      .ds.w   1
_VID_vde::      .ds.w   1

_bgcol::        .ds.w   1 ; temp
