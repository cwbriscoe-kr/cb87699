with base as (
select pie.sku_nbr                 as sku_nbr
      ,pie.seq_nbr                 as seq_nbr
      ,pie.err_msg                 as error_message
      ,substr(pie.meta_data,16,14) as mag_case
      ,substr(pie.meta_data,30,14) as mag_base
      ,desc_lng_txt                as description
      ,fi1.ft_lvl06_cd || '/' ||
       fi1.ft_lvl08_cd || '/' ||
       fi1.ft_lvl09_cd             as dpt_cls_scl
      ,pie.tran_lvl                as tran_level
      ,pie.tran_typ                as tran_type
      ,pie.err_cd                  as error_code
      ,substr(pie.meta_data,9,1)   as qtype
      ,substr(pie.meta_data,1,8)   as qsource
      ,case is2.sku_typ_cd
       when '55' then
         'Y'
       else
         ' '
       end                         as set_sku
      ,is2.rec_stat_cd             as sku_sts
  from prd.pie_pid_int_errs pie
      ,prd.is2_itm_sku      is2
      ,prd.fi1_ft_itm       fi1
 where pie.sku_nbr        = is2.sku_nbr
   and fi1.itm_nbr        = is2.itm_nbr
   and fi1.eff_fr_dt     <= current date
   and fi1.eff_to_dt      > current date
--   and fi1.ft_lvl09_cd    = '009'
)
select base.sku_nbr
      ,base.mag_case
      ,base.mag_base
      ,base.dpt_cls_scl
      ,base.tran_level
      ,base.tran_type
      ,base.error_code
      ,base.set_sku
      ,base.sku_sts
  from base 
 where base.seq_nbr = 1
 order by base.sku_nbr, base.seq_nbr
  with ur
;