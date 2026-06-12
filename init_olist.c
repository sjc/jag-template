//
// init_olist.c
// Build initial object lists
//

#include "olist.h"

/* Object List Setup
 *
 * `_OLPStore` is the master OP list which will be drawn each frame. It
 * has been set up with leading BRANCH objects in `InitLister()` and will
 * be installed by `GPU_init()` in gpures.s.
 *
 * `InitObjectList()` below is called from `InitLister()` and will be used
 * to set up the contents of the OP lists, using the slightly more expresive
 * C interface provided in olist.c/.h. These lists should contain everything
 * which follows the BRANCH objects.
 *
 * `_OList` points to the current active OP list. Each vertical blank this
 * list will be copied into `_OLPStore` after the branch objects.
 */

extern int packed_olist[]; // storage for the olist we're going to build

extern int vidmem[]; // buffer for bitmap image

#define BMP_WIDTH   320             // Width in Pixels
#define BMP_HEIGHT  200             // Height in Pixels

#define SCREENX     (18+(320-BMP_WIDTH)/2)
#define SCREENY     (20+(240-BMP_HEIGHT))

#define PPP         8
#define PHRASES     (BMP_WIDTH/PPP)

#define OLIST_LEN   2

union olist SingleBitmapList[OLIST_LEN] = {
    {{OL_BITMAP, SCREENX, SCREENY, 
        0L, &vidmem, BMP_HEIGHT, PHRASES, PHRASES, 
        3, 1, 0, OL_RELEASE, 0, 0,0,0
    }},
    {{OL_STOP}},
};

void InitObjectList() {

    // build the Object List from the definition above
    OLbldto(SingleBitmapList, packed_olist, OLIST_LEN);

    // assign it as the current OList
    OLPset(packed_olist);
}
