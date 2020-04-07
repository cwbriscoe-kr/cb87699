with base as (
select pie.sku_nbr                 as sku_nbr
      ,pie.seq_nbr                 as seq_nbr
      ,pie.err_msg                 as error_message
      ,substr(pie.meta_data,16,14) as mag_case
      ,substr(pie.meta_data,30,14) as mag_base
      ,desc_lng_txt                as description
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
      ,is2.rec_stat_cd             as sku_stat
  from prd.pie_pid_int_errs pie
      ,prd.is2_itm_sku is2
      ,prd.sl4_sku_loc sl4
 where pie.sku_nbr  = is2.sku_nbr
   and sl4.sku_nbr  = is2.sku_nbr
   and sl4.loc_nbr = '35579'
   and sl4.rec_stat_cd = '01'
)
select base.sku_nbr
      ,base.mag_case
      ,base.mag_base
      ,base.tran_level
      ,base.tran_type
      ,base.error_code
      ,base.sku_stat
  from base 
 where base.seq_nbr = 1
   and set_sku != 'Y'
 order by sku_nbr
--  order by base.error_code
  with ur
;