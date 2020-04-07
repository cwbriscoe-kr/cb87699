with magbas as (
  select is2.sku_nbr         as sku
        ,sv1.mstr_art_typ_cd as magcas_type
        ,sv1.mstr_art_nbr    as magcas
        ,va1.art_nbr_id_cd   as magbas_type
        ,va1.art_nbr         as magbas
--        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13) as pidcas
--        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),1,1)
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),3,1)     
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),2,1)     
--         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),4,10),13) as pidbas
        ,is2.rec_stat_cd as sku_sts
    from prd.is2_itm_sku      is2
        ,prd.va1_vndr_art     va1
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.sc9_set_sku_comp sc9
   where va1.sku_nbr            = is2.sku_nbr
     and va1.vndr_nbr           = is2.vndr_nbr
     and va1.sku_nbr            = sv1.sku_nbr
     and va1.vndr_nbr           = sv1.vndr_nbr
     and is2.sku_nbr            = sc9.sku_nbr
     and sc9.comp_sku_seq_nbr   = 1
     and sv1.prmy_altn_vndr_ind = 'P'
     and is2.sku_typ_cd         = '55'
     and va1.bas_arl_fl         = 'B'
     and is2.rec_stat_cd  between '20' and '60'
     and sv1.mstr_art_nbr      != va1.art_nbr
     and not (sv1.mstr_art_typ_cd = 'CS' and va1.art_nbr_id_cd = 'IH')
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
     and length(ltrim(rtrim(va1.art_nbr))) > 0
)
select *
  from magbas
  with ur
;