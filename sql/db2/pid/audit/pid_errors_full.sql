with base as (
select pgm_nm                   as sku_nbr
      ,substr(parm_txt_2,1,72)  as error_message
      ,substr(parm_txt_1,16,14) as mag_case
      ,substr(parm_txt_1,30,14) as mag_base
      ,substr(parm_txt_1,44,5)  as whse_nbr
      ,desc_lng_txt             as description
      ,substr(parm_txt_1,10,3)  as tran_level
      ,substr(parm_txt_1,13,3)  as tran_type
      ,rqst_nbr                 as error_code
      ,substr(parm_txt_1,9,1)   as qtype
      ,substr(parm_txt_1,1,8)   as qsource
  from prd.jl1_job_log jl1
      ,prd.is2_itm_sku is2
 where jl1.job_nm  = 'UACPID00'
   and jl1.step_nm = 'ERRLOG'
   and jl1.pgm_nm  = is2.sku_nbr
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
  from prd.jl1_job_log      jl1
      ,prd.is2_itm_sku      is2
      ,prd.fi1_ft_itm       fi1
      ,prd.sv1_sku_vndr_dtl sv1
 where jl1.job_nm             = 'UACPID00'
   and jl1.step_nm            = 'ERRLOG'
   and jl1.pgm_nm             = is2.sku_nbr
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
         'CASE UPC (M/P) ' || rtrim(base.mag_case) 
         || '/' || data.pid_case_x || 
         ' NOT YET ON PID CASE FILE'
       when '00337' then
         'THE CONS UPC MUST BE LEVEL 1 OR 2. '
--         'THE LEVEL 1 IS ' ||
--         coalesce((
--           select con_upc_no
--             from accp.k15_pid_casco
--            where cas_upc_no = data.pid_case_t
--              and con_typ_cd = 1
--          ),'?????????????')
       when '00432' then
         'CASE UPC (M/P) ' || rtrim(base.mag_case) 
         || '/' || data.pid_case_x || 
         ' ALREADY EXISTS FOR WHSE ' || base.whse_nbr
       when '03718' then
         'FREDMEYER FT ''' || data.lvl06 || ' ' ||
         data.lvl08 || ' ' || data.lvl09 ||
         ''' FOR THIS ITEM IS NOT FOUND ON PIDSBCOM'
       else
         base.error_message
       end), base.error_message) as error_message
      ,base.mag_case
      ,base.mag_base
      ,base.description
      ,base.tran_level
      ,base.tran_type
      ,base.error_code
      ,base.qtype
      ,base.qsource
  from base left outer join data
    on base.sku_nbr = data.sku_nbr
 order by sku_nbr
  with ur
;