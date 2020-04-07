with base as (
select pie.sku_nbr                 as sku_nbr
      ,pie.seq_nbr                 as seq_nbr
      ,substr(pie.err_msg,1,72)    as error_message
      ,substr(pie.meta_data,16,14) as mag_case
      ,substr(pie.meta_data,30,14) as mag_base
      ,substr(pie.meta_data,44,5)  as whse_nbr
      ,is2.desc_lng_txt            as description
      ,substr(pie.meta_data,10,3)  as tran_level
      ,substr(pie.meta_data,13,3)  as tran_type
      ,pie.err_cd                  as error_code
      ,substr(pie.meta_data,49,4)  as fail_cnt
      ,substr(pie.meta_data,9,1)   as qtype
      ,substr(pie.meta_data,1,8)   as qsource
  from accp.pie_pid_int_errs pie
      ,accp.is2_itm_sku      is2
 where pie.sku_nbr  = is2.sku_nbr
),
data as (
select is2.sku_nbr                        as sku_nbr
      ,digits(decimal(fi1.ft_lvl06_cd,4)) as lvl06
      ,digits(decimal(fi1.ft_lvl08_cd,4)) as lvl08
      ,digits(decimal(fi1.ft_lvl09_cd,4)) as lvl09
      ,char(substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),1,13),13)   as pid_case_x
      ,char(substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),1,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),3,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),2,1) ||
       substr(digits(decimal(rtrim(
       sv1.mstr_art_nbr),14)),4,10),13)   as pid_case_t
      ,is2.fsa_flg                        as mag_fsa_fl
  from accp.pie_pid_int_errs pie
      ,accp.is2_itm_sku      is2
      ,accp.fi1_ft_itm       fi1
      ,accp.sv1_sku_vndr_dtl sv1
 where pie.sku_nbr            = is2.sku_nbr
   and pie.seq_nbr            = 1
   and sv1.vndr_nbr           = is2.vndr_nbr
   and sv1.sku_nbr            = is2.sku_nbr
   and sv1.prmy_altn_vndr_ind = 'P'
   and fi1.itm_nbr            = is2.itm_nbr
   and fi1.eff_fr_dt         <= current date
   and fi1.eff_to_dt          > current date
)
select base.sku_nbr
      ,coalesce((case base.error_code
       when '00320' then
         'CASE UPC ' || data.pid_case_x || 
         ' NOT YET ON PID CASE FILE'
       when '00337' then
         'THE CONS UPC MUST BE LEVEL 1 OR 2. '
--         || 'THE LEVEL 1 IS ' ||
--         case
--         when data.pid_case_t is not null then
--         coalesce((
--           select con_upc_no
--             from accp.k15_pid_casco
--            where cas_upc_no = data.pid_case_t
--              and con_typ_cd = 1
--          ),'?????????????')
--          else
--            '?????????????'
--          end
       when '00432' then
         'CASE UPC ' || data.pid_case_x || 
         ' ALREADY EXISTS FOR WHSE ' || base.whse_nbr
       when '03718' then
         'FREDMEYER FT ''' || data.lvl06 || ' ' ||
         data.lvl08 || ' ' || data.lvl09 ||
         ''' FOR THIS ITEM IS NOT FOUND ON PIDSBCOM'
       when '03920' then
         'FSA FLAG MISMATCH.  MAGIC FSA_FLG=' || data.mag_fsa_fl
       when '04280' then
         'UPC ' || data.pid_case_x || 
         ' IS CIM CONVERTED, AND MAY ONLY BE MODIFIED BY CIM'
       else
         base.error_message
       end), base.error_message) as error_message
      ,base.mag_case
      ,base.mag_base
      ,base.description
      ,base.tran_level
      ,base.tran_type
      ,base.error_code
      ,base.fail_cnt
      ,base.qtype
      ,base.qsource
  from base left outer join data
    on base.sku_nbr = data.sku_nbr
-- where data.sku_nbr = '01035643'
--   where base.error_code = '03920'
 where data.sku_nbr between '00000000' and '10000000'
 order by sku_nbr, seq_nbr
  with ur
;