with magca_1 as (
  select sv1.vndr_nbr      as vndr
        ,sv1.mstr_art_nbr  as mupc
    from prd.is2_itm_sku      is2
        ,prd.sv1_sku_vndr_dtl sv1
   where sv1.sku_nbr        = is2.sku_nbr
     and is2.rec_stat_cd   in ('20','30')
group by sv1.vndr_nbr, sv1.mstr_art_nbr
),

magca_2 as (
  select is2.vndr_nbr      as vndr
        ,va1.art_nbr       as mupc
    from prd.is2_itm_sku      is2
        ,prd.va1_vndr_art     va1
   where va1.sku_nbr        = is2.sku_nbr
     and is2.rec_stat_cd   in ('20', '30')
     and va1.art_nbr_id_cd in ('CA', 'CK')
group by is2.vndr_nbr, va1.art_nbr
),

magca_3 as (
  select * from magca_1 
   union 
  select * from magca_2
group by vndr, mupc
),

magcas as (
  select vndr
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),4,10),13) as pupc
        ,mupc
    from magca_3
),

mfgid_1 as (
  select vndr
        ,'0'||substr(pupc, 2, 7) as mfgid
        ,mupc
    from magcas
)

  select vndr
        ,mupc
        ,mfgid
    from mfgid_1
group by vndr, mupc, mfgid
order by vndr, mupc, mfgid