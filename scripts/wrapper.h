#include "hts.h"
#include "vcf.h"
#include "sam.h"
#include "hfile.h"
#include "cram.h"
#include "bgzf.h"
#include "vcfutils.h"
#include "tbx.h"
#include "synced_bcf_reader.h"
#include "kbitset.h"
#include "faidx.h"
#include "thread_pool.h"

// The following functions have to be wrapped here because they are inline in htslib.

/**
 * <div rustbindgen replaces="kbs_init2"></div>
 */
kbitset_t *wrap_kbs_init2(size_t ni, int fill);

/**
 * <div rustbindgen replaces="kbs_init"></div>
 */
kbitset_t *wrap_kbs_init(size_t ni);

/**
 * <div rustbindgen replaces="kbs_insert"></div>
 */
void wrap_kbs_insert(kbitset_t *bs, int i);

/**
 * <div rustbindgen replaces="kbs_destroy"></div>
 */
void wrap_kbs_destroy(kbitset_t *bs);

int hts_mojo_sam_itr_next(htsFile *fp, hts_itr_t *itr, bam1_t *b);
