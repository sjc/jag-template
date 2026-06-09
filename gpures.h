//
// gpures.h
// C interface to GPU-resident routines
//

#ifndef GPURES_H
#define GPURES_H

extern void GPU_done(void);

extern void GPU_wait_blitter_ready(void);

extern void GPU_blit_and_wait(int src, int dst, int len);

extern void GPU_blit(int src, int dst, int len);

extern void GPU_wait_vblank(void);

#endif // GPURES_H
