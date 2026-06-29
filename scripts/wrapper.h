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
uint8_t *hts_mojo_bam_aux_get(const bam1_t *b, const char *tag);
int hts_mojo_bam_aux_update_int(bam1_t *b, const char *tag, int64_t val);
int hts_mojo_bam_aux_update_float(bam1_t *b, const char *tag, float val);
int hts_mojo_bam_aux_update_str(
    bam1_t *b, const char *tag, int len, const char *data
);
int hts_mojo_bam_aux_del_by_tag(bam1_t *b, const char *tag);
const char *hts_mojo_bam_aux_tag(const uint8_t *s);
int hts_mojo_hts_set_opt_int(htsFile *fp, enum hts_fmt_option opt, int value);
int hts_mojo_hts_set_opt_str(
    htsFile *fp, enum hts_fmt_option opt, const char *value
);

typedef struct hts_mojo_bam_plp_data_t {
    htsFile *fp;
    sam_hdr_t *hdr;
    hts_itr_t *itr;
    int last_status;
} hts_mojo_bam_plp_data_t;

bam_plp_t hts_mojo_bam_plp_init(hts_mojo_bam_plp_data_t *data);
