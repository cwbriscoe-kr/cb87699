select fi1.ft_lvl06_cd
      ,fi1.ft_lvl07_cd
      ,fi1.ft_lvl08_cd
      ,fi1.ft_lvl09_cd
      ,is2.sku_nbr
      ,is2.sku_typ_cd
      ,is2.rec_stat_cd
      ,is2.desc_lng_txt
      ,sv1.vndr_nbr
      ,sv1.prmy_altn_vndr_ind
      ,sv1.mstr_art_nbr
      ,va1.art_nbr
      ,va1.art_nbr_id_cd
      ,va1.art_4680_nbr
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm  fi1
      ,prd.sv1_sku_vndr_dtl sv1
      ,prd.va1_vndr_art va1
      ,prd.pie_pid_int_errs pie
 where is2.itm_nbr = fi1.itm_nbr
   and is2.sku_nbr = sv1.sku_nbr
   and is2.vndr_nbr = sv1.vndr_nbr
   and sv1.sku_nbr = va1.sku_nbr
   and sv1.vndr_nbr = va1.vndr_nbr
   and va1.sku_nbr = pie.sku_nbr
   and pie.seq_nbr = 1
   and sv1.prmy_altn_vndr_ind = 'P'
   and sv1.mstr_art_typ_cd = 'CS'
   and is2.rec_stat_cd < '80'
   and fi1.ft_lvl06_cd = 76
   and not exists (
       select 1
         from prd.va1_vndr_art va2
        where va2.sku_nbr = va1.sku_nbr
          and va2.vndr_nbr = va1.vndr_nbr
          and va2.art_nbr_id_cd = 'IH')
order by 1,2,3,4;
