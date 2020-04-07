with magca_1 as (
  select sv1.vndr_nbr      as vndr
        ,ltrim(rtrim(sv1.mstr_art_nbr))  as mupc
        ,sv1.sku_nbr       as sku
        ,is2.rec_stat_cd   as stat
    from prd.is2_itm_sku      is2
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.pie_pid_int_errs pie
   where sv1.sku_nbr        = is2.sku_nbr
     and sv1.vndr_nbr       = is2.vndr_nbr
     and is2.sku_nbr        = pie.sku_nbr
     and pie.seq_nbr        = 1
     and pie.err_cd         = '00783'
     and is2.rec_stat_cd   between '20' and '60'
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
group by sv1.vndr_nbr, sv1.mstr_art_nbr, sv1.sku_nbr, is2.rec_stat_cd
),

magca_2 as (
  select is2.vndr_nbr      as vndr
        ,va1.art_nbr       as mupc
        ,is2.sku_nbr       as sku
        ,is2.rec_stat_cd   as stat
    from prd.is2_itm_sku      is2
        ,prd.va1_vndr_art     va1
        ,prd.pie_pid_int_errs pie
   where va1.sku_nbr        = is2.sku_nbr
     and is2.sku_nbr        = pie.sku_nbr
     and pie.seq_nbr        = 1
     and pie.err_cd         = '00783'
     and is2.rec_stat_cd   between '20' and '30'
     and va1.art_nbr_id_cd in ('CA', 'CK', 'CS', 'CE')
     and va1.bas_arl_fl = 'B'
group by is2.vndr_nbr, va1.art_nbr, is2.sku_nbr, is2.rec_stat_cd
),

magca_3 as (
  select * from magca_1 
--   union 
--  select * from magca_2
group by vndr, mupc, sku, stat
),

magcas as (
  select vndr
        ,mupc
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),4,10),13) as pupc
        ,sku
        ,stat
    from magca_3
),

mfgid_1 as (
  select vndr
        ,'0'||substr(pupc,2,7) as mfgid
        ,'0'||substr(pupc,1,7) as mfgid2
        ,'0'||substr(pupc,3,7) as mfgid3
        ,mupc
        ,pupc
        ,sku
        ,stat
    from magcas
),

mfgid as (
  select vndr
        ,mfgid
        ,mfgid2
        ,mfgid3
        ,mupc
        ,pupc
        ,sku
        ,stat
    from mfgid_1
group by vndr, mfgid, mfgid2, mfgid3, mupc, pupc, sku, stat
)

select mfgid.mfgid
      ,mfgid.mfgid2
      ,mfgid.mfgid3
      ,mfgid.vndr
      ,vd1.vndr_nm
      ,mfgid.mupc
      ,mfgid.pupc
      ,mfgid.sku
      ,mfgid.stat
      ,sv1.mdse_flow_cd as flow
  from mfgid, prd.vd1_vndr_dtl vd1, prd.sv1_sku_vndr_dtl sv1
 where mfgid.vndr = vd1.vndr_nbr
   and mfgid.vndr = sv1.vndr_nbr
   and mfgid.sku  = sv1.sku_nbr
order by mfgid, vndr, sku;