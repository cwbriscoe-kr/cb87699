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
      ,substr(digits(decimal(rtrim(sv1.mstr_art_nbr),14)),1,13) as pid_cas
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
 where pie.sku_nbr = sv1.sku_nbr
   and pie.tran_lvl = 'WHS'
   and sv1.prmy_altn_vndr_ind = 'P'
order by pie.err_cd, pie.sku_nbr, pie.seq_nbr
),
data as (
select report.sku_nbr
      ,casco.con_upc_no
  from report
      ,prd.k15_pid_casco casco
 where report.pid_tbl_cas = casco.cas_upc_no
   and casco.con_typ_cd = '1'
   and other_err_cd = '03747'
),
bupc as (
  select data.con_upc_no as oupc
        ,data.con_upc_no as bupc
    from data
),
gupc as (
  select oupc
        ,substr(bupc,1,1)||substr(bupc,3,1)
       ||substr(bupc,2,1)||substr(bupc,4,10) as gupc
    from bupc
),
chkdgt1 as (
  select oupc
        ,cast (substr(gupc,1,1) as integer) as d1
        ,cast (substr(gupc,2,1) as integer) as d2
        ,cast (substr(gupc,3,1) as integer) as d3
        ,cast (substr(gupc,4,1) as integer) as d4
        ,cast (substr(gupc,5,1) as integer) as d5
        ,cast (substr(gupc,6,1) as integer) as d6
        ,cast (substr(gupc,7,1) as integer) as d7
        ,cast (substr(gupc,8,1) as integer) as d8
        ,cast (substr(gupc,9,1) as integer) as d9
        ,cast (substr(gupc,10,1) as integer) as d10
        ,cast (substr(gupc,11,1) as integer) as d11
        ,cast (substr(gupc,12,1) as integer) as d12
        ,cast (substr(gupc,13,1) as integer) as d13
    from gupc
),
chkdgt2 as (
  select oupc
        ,d1*3+d2*1+d3*3+d4*1+d5*3+d6*1+d7*3
        +d8*1+d9*3+d10*1+d11*3+d12*1+d13*3  as chksum
    from chkdgt1
),
chkdgt3 as (
  select oupc
        ,((chksum/10)*10+10) - chksum as digit
    from chkdgt2
),
chkdgt as (
  select oupc
        ,case
           when digit = 10 then
             '0'
           else
             substr(digits(digit),10,1)
         end as chkdgt 
    from chkdgt3
),
magupc as (
  select gupc.oupc
        ,case
         when substr(gupc.gupc,1,5) = '00400' then
           (gupc.gupc)||'0'
         when substr(gupc.gupc,1,5) = '00410' then
           (gupc.gupc)||'0'
         else
           (gupc.gupc)||(chkdgt.chkdgt)
         end as magupc
    from gupc, chkdgt
   where gupc.oupc = chkdgt.oupc
)
select data.sku_nbr
      ,magupc.magupc as new_bas_upc
  from data,magupc
 where data.con_upc_no = magupc.oupc
 order by sku_nbr
with ur
;