
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
      ,case is2.sku_typ_cd
       when '55' then
         'Y'
       else
         'N'
       end as set_sku
      ,is2.rec_stat_cd as sku_sts
      ,sv1.mstr_art_nbr as mag_cas
      ,va1.art_nbr as mag_bas
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
      ,fi1.ft_lvl06_cd || '/' ||
       fi1.ft_lvl08_cd || '/' ||
       fi1.ft_lvl09_cd as dpt_cls_scl
      ,substr(pie.err_msg,1,70) as err_msg
      ,coalesce((select othererr.msg from othererr
                 where othererr.sku = pie.sku_nbr),'NONE') as other_err_msg
      ,coalesce((select other_err_cd from othererr
                 where othererr.sku = pie.sku_nbr), '     ') as other_err_cd
      ,coalesce((select qty from prd.oh3_skc_oh
                  where sku_nbr = is2.dec_sku_nbr
                    and loc_nbr = 65
                    and perd_fr_dt = '2014-05-11'), 0) as whs_oh_qty
      ,coalesce((select sum(qty) from prd.oo3_skc_oo
                  where sku_nbr = is2.dec_sku_nbr
                    and loc_nbr = 65
                    and perd_fr_dt = '2014-05-11'), 0) as whs_oo_qty
      ,pie.tran_typ as type
      ,pie.rec_crt_dt as error_date
  from prd.pie_pid_int_errs pie
      ,prd.sv1_sku_vndr_dtl sv1
      ,prd.is2_itm_sku      is2
      ,prd.fi1_ft_itm       fi1
      ,prd.va1_vndr_art     va1
 where pie.sku_nbr            = is2.sku_nbr
   and is2.sku_nbr            = sv1.sku_nbr
   and fi1.itm_nbr            = is2.itm_nbr
   and va1.sku_nbr            = sv1.sku_nbr
   and va1.vndr_nbr           = sv1.vndr_nbr
   and va1.bas_arl_fl         = 'B'
   and sv1.prmy_altn_vndr_ind = 'P'
   and fi1.eff_fr_dt         <= current date
   and fi1.eff_to_dt          > current date
   and pie.tran_lvl           = 'WHS'
--   and pie.tran_typ           = 'ADD'
--   and pie.seq_nbr            = 1
)

--select err_cd
--      ,sku_nbr
--      ,mag_cas_p
--      ,mag_bas_p
--      ,pid_bas
select *
from report
--where sku_nbr = '03186251'
--where other_err_cd = '00783'
order by other_err_cd, err_cd, sku_nbr
with ur
;