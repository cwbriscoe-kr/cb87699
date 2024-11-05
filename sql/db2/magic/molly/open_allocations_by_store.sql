select ol2.org_co_id as co_id
      ,ol2.org_rgn_id as rgn_id
      ,ad9.loc_nbr as loc
      ,tc2.po_id as po
      ,li2.sku_nbr as sku
      ,ad9.alc_qty as qty
      ,sl4.mdse_flow_cd as flow_cd
      ,is2.desc_lng_txt as desc
  from prd.tc2_po_trm_cond tc2
      ,prd.li2_po_ln_itm li2
      ,prd.ad9_alc_dtl ad9
      ,prd.sl4_sku_loc sl4
      ,prd.is2_itm_sku is2
      ,prd.ol2_org_loc ol2
 where tc2.po_id = li2.po_id
   and ad9.po_tfr_nbr = li2.po_id
   and ad9.ln_seq_nbr = li2.po_ln_seq_nbr
   and sl4.sku_nbr = li2.sku_nbr
   and sl4.loc_nbr = ad9.loc_nbr
   and is2.sku_nbr = li2.sku_nbr
   and ol2.loc_id = sl4.loc_nbr
   and sl4.loc_nbr like '50%'
   and tc2.po_stat_cd in ('ON','OR')
   and li2.ln_itm_stat_cd = 'O'
   and alc_qty > 0
 order by ad9.loc_nbr, tc2.po_id, li2.sku_nbr
  with ur;
