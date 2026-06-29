#include "wrapper.h"

kbitset_t *wrap_kbs_init2(size_t ni, int fill)
{
    return kbs_init2(ni, fill);
}

kbitset_t *wrap_kbs_init(size_t ni)
{
    return wrap_kbs_init2(ni, 0);
}

void wrap_kbs_insert(kbitset_t *bs, int i)
{
    kbs_insert(bs, i);
}

void wrap_kbs_destroy(kbitset_t *bs)
{
    kbs_destroy(bs);
}

int hts_mojo_sam_itr_next(htsFile *fp, hts_itr_t *itr, bam1_t *b)
{
    return sam_itr_next(fp, itr, b);
}

uint8_t *hts_mojo_bam_aux_get(const bam1_t *b, const char *tag)
{
    return bam_aux_get(b, tag);
}

int hts_mojo_bam_aux_update_int(bam1_t *b, const char *tag, int64_t val)
{
    return bam_aux_update_int(b, tag, val);
}

int hts_mojo_bam_aux_update_float(bam1_t *b, const char *tag, float val)
{
    return bam_aux_update_float(b, tag, val);
}

int hts_mojo_bam_aux_update_str(
    bam1_t *b, const char *tag, int len, const char *data
)
{
    return bam_aux_update_str(b, tag, len, data);
}

int hts_mojo_bam_aux_del_by_tag(bam1_t *b, const char *tag)
{
    uint8_t *aux = bam_aux_get(b, tag);
    if (aux == NULL) {
        return 1;
    }
    return bam_aux_del(b, aux);
}

const char *hts_mojo_bam_aux_tag(const uint8_t *s)
{
    return bam_aux_tag(s);
}

static int hts_mojo_bam_plp_auto_next(void *data, bam1_t *b)
{
    hts_mojo_bam_plp_data_t *bridge = (hts_mojo_bam_plp_data_t *)data;
    if (bridge == NULL || bridge->fp == NULL || bridge->hdr == NULL) {
        return -2;
    }

    if (bridge->itr != NULL) {
        bridge->last_status = sam_itr_next(bridge->fp, bridge->itr, b);
        return bridge->last_status;
    }

    bridge->last_status = sam_read1(bridge->fp, bridge->hdr, b);
    return bridge->last_status;
}

bam_plp_t hts_mojo_bam_plp_init(hts_mojo_bam_plp_data_t *data)
{
    if (data != NULL) {
        data->last_status = 0;
    }
    return bam_plp_init(hts_mojo_bam_plp_auto_next, data);
}
