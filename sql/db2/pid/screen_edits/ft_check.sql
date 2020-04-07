select sbcom.lfo_grp_cls_id || sbcom.lfo_grp_sub_id as sbcom
  from prd.pid_sbcom sbcom
      ,prd.pid_pdtca pdtca
 where pdtca.lfo_grp_cls_id = sbcom.lfo_grp_cls_id
   and pdtca.lfo_grp_sub_id = sbcom.lfo_grp_sub_id
   and sbcom.fam_dpt_cd = '0051'
   and sbcom.fam_cls_cd = '0910'
   and sbcom.fam_sbc_cd = '0883'
   and pdtca.cas_upc_no = '0400086292153'
  with ur
;

select digits(decimal(fi1.ft_lvl06_cd,4)) as fam_dpt_cd
      ,digits(decimal(fi1.ft_lvl08_cd,4)) as fam_cls_cd
      ,digits(decimal(fi1.ft_lvl09_cd,4)) as fam_sbc_cd
  from prd.fi1_ft_itm  fi1
      ,prd.is2_itm_sku is2
 where is2.itm_nbr     = fi1.itm_nbr
   and fi1.rec_stat_cd = '01'
   and is2.sku_nbr     = '00474740'
  with ur
;

--experiment
with mag as (
  select '00400862921534' as upc
    from prd.pid_sbcom
   fetch first row only
)
select sbcom.lfo_grp_cls_id || sbcom.lfo_grp_sub_id as sbcom
      
  from prd.pid_sbcom sbcom
      ,prd.pid_pdtca pdtca
      ,mag
 where pdtca.lfo_grp_cls_id = sbcom.lfo_grp_cls_id
   and pdtca.lfo_grp_sub_id = sbcom.lfo_grp_sub_id
   and sbcom.fam_dpt_cd = '0051'
   and sbcom.fam_cls_cd = '0910'
   and sbcom.fam_sbc_cd = '0883'
   and pdtca.cas_upc_no = 
       CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mag.upc),14)),1,1)
       ||SUBSTR(DIGITS(DECIMAL(RTRIM(mag.upc),14)),3,1)     
       ||SUBSTR(DIGITS(DECIMAL(RTRIM(mag.upc),14)),2,1)     
       ||SUBSTR(DIGITS(DECIMAL(RTRIM(mag.upc),14)),4,10),13)   
  with ur
;