with othererr as (
  select sku_nbr as sku
        ,tran_lvl || ' ' || err_cd || ' ' || substr(err_msg,1,70) as msg
        ,err_cd as other_err_cd
    from prd.pie_pid_int_errs
   where seq_nbr = 1
     and tran_lvl != 'WHS'
),
report as (
select pie.err_cd
      ,pie.sku_nbr
      ,sv1.mstr_art_nbr as mag_cas
      ,substr(digits(decimal(rtrim(sv1.mstr_art_nbr),14)),1,13) as mag_cas_p
      ,substr(digits(decimal(rtrim(va1.art_nbr),14)),1,13) as mag_bas_p
      ,char(substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),1,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),3,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),2,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),4,10),13)   as pid_tbl_cas
      ,substr(pie.err_msg,1,70) as err_msg
      ,coalesce((select othererr.msg from othererr
                 where othererr.sku = pie.sku_nbr),'NONE') as other_err_msg
      ,coalesce((select other_err_cd from othererr
                 where othererr.sku = pie.sku_nbr), '     ') as other_err_cd
  from prd.pie_pid_int_errs pie
      ,prd.sv1_sku_vndr_dtl sv1
      ,prd.va1_vndr_art     va1
 where pie.sku_nbr = sv1.sku_nbr
   and sv1.sku_nbr = va1.sku_nbr
   and sv1.vndr_nbr = va1.vndr_nbr
   and va1.bas_arl_fl = 'B'
   and pie.tran_lvl = 'WHS'
   and sv1.prmy_altn_vndr_ind = 'P'
order by pie.err_cd, pie.sku_nbr, pie.seq_nbr
),
data as (
select report.sku_nbr
      ,report.mag_cas_p
      ,report.mag_bas_p
      ,substr(casco.cas_upc_no,1,1) ||
       substr(casco.cas_upc_no,3,1) ||
       substr(casco.cas_upc_no,2,1) ||
       substr(casco.cas_upc_no,4,10) as cas_upc_no
      ,substr(casco.con_upc_no,1,1) ||
       substr(casco.con_upc_no,3,1) ||
       substr(casco.con_upc_no,2,1) ||
       substr(casco.con_upc_no,4,10) as con_upc_no
  from report
      ,prd.k15_pid_casco casco
 where report.pid_tbl_cas = casco.cas_upc_no
   and casco.con_typ_cd = '1'
   and other_err_cd = '03747'
)
select * 
  from data
 where substr(con_upc_no,1,5) != '00400'
 order by sku_nbr
with ur
;