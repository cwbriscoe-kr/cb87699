  select sv1.sku_nbr
        ,sv1.vndr_nbr
        ,sv1.mstr_art_nbr
        ,va1.art_nbr
        ,va1.art_nbr_id_cd
    from prd.is2_itm_sku      is2
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.va1_vndr_art     va1
   where is2.sku_nbr        = sv1.sku_nbr
     and sv1.sku_nbr        = va1.sku_nbr
     and sv1.vndr_nbr       = va1.vndr_nbr
     and is2.rec_stat_cd   in ('20','30')
     and is2.sku_typ_cd    != 'DS'
order by sv1.sku_nbr
        ,sv1.vndr_nbr
        ,sv1.mstr_art_nbr
        ,va1.art_nbr
;;