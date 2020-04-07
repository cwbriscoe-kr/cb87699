select distinct(stat_ind)
  from prd.PP1_MDSE_PRC_PND
 --where n_for_qty > 0
  --where sku_nbr = '02384412'
   --and loc_nbr = '00035'
  ;

select *
  from prd.PM2_MDSE_PRC_MSTR
 --where n_for_qty > 0
 where sku_nbr = '02384412'
   and loc_nbr = '00035'
  ;

select *
  from prd.VA1_VNDR_ART
 where art_4680_nbr = 0087129500706
 ;

WITH UPCTYP AS (                          
  SELECT SUBSTR(TBL_ELEM_ID,1,2) AS CODE  
    FROM prd.TD1_TBL_DTL                      
   WHERE TBL_ID   = 'T013'                
     AND SUBSTR(TBL_ELEM_TEXT,45,1) = 'Y' 
     AND ORG_CO_NBR  = '1'                
     AND ORG_RGN_NBR = '00'               
), current_price as (                                     
select pm2.loc_nbr
      ,DIGITS(VA1.ART_4680_NBR) as upc
      ,'001' as qty
      ,substr(digits(cast(
       pm2.fix_unt_prc_amt * 100 as integer)),4,7) as prc
      ,case
       when n_for_qty > 0 then
         substr(digits(cast(
         pm2.n_for_qty as integer)),7,3)
       else
         case 
         when temp_unt_prc_amt > 0 then
           '001'
         else
           '000'
         end
       end as n_for_qty
      ,case
       when n_for_prc_amt > 0 then
         substr(digits(cast(
         pm2.n_for_prc_amt * 100 as integer)),4,7)
       else
         case
         when temp_unt_prc_amt > 0 then
           substr(digits(cast(
           pm2.temp_unt_prc_amt * 100 as integer)),4,7)
         else
           '0000000'
         end
       end as n_for_prc
      ,pm2.eff_fr_dt
      ,pm2.eff_to_dt
      ,pm2.sku_nbr
  from prd.PM2_MDSE_PRC_MSTR pm2
      ,prd.IS2_ITM_SKU       is2
      ,prd.VA1_VNDR_ART      va1
      ,upctyp
 where is2.sku_nbr = pm2.sku_nbr
   and pm2.sku_nbr = va1.sku_nbr
   and pm2.loc_nbr < '01000'
   and pm2.loc_nbr != '00300'
   and is2.rec_stat_cd in ('10','20','30','40','50')
   and is2.sku_typ_cd in
      ('01', '02', '03', '04', '05', '12', '19',      
       '20', '21', '22', '23', '25', '55', '65', '68')
   and is2.rec_crt_dt < current date
   and pm2.eff_to_dt >= current date
   and (va1.art_nbr_id_cd = upctyp.code
    or  va1.art_nbr_id_cd = 'IH'
   and  is2.sku_typ_cd = '68')
), future_price as (
select pp1.loc_nbr
      ,DIGITS(VA1.ART_4680_NBR) as upc
      ,case
       when perm_temp_ind = 'P' then
         '001'
       else
         '000'
       end as qty
      ,case when perm_temp_ind = 'P' then
         substr(digits(cast(
         pp1.fix_unt_prc_amt * 100 as integer)),4,7)
       else
         '0000000'
       end as prc
      ,case 
       when perm_temp_ind = 'T' then
         case
         when n_for_qty > 0 then
           substr(digits(cast(
           pp1.n_for_qty as integer)),7,3)
         else
           '001'
         end
       else
        '000'
       end as n_for_qty
      ,case
       when perm_temp_ind = 'T' then
         case
         when n_for_prc_amt > 0 then
           substr(digits(cast(
           pp1.n_for_prc_amt * 100 as integer)),4,7)
         else
           substr(digits(cast(
           pp1.fix_unt_prc_amt * 100 as integer)),4,7)
         end
       else
         '0000000'
       end as n_for_prc
      ,pp1.eff_fr_dt
      ,pp1.eff_to_dt
      ,pp1.sku_nbr
  from prd.PP1_MDSE_PRC_PND  pp1
      ,prd.IS2_ITM_SKU       is2
      ,prd.VA1_VNDR_ART      va1
      ,upctyp
 where is2.sku_nbr = pp1.sku_nbr
   and pp1.sku_nbr = va1.sku_nbr
   and pp1.loc_nbr < '01000'
   and pp1.loc_nbr != '00300'
   and is2.rec_stat_cd in ('10','20','30','40','50')
   and is2.sku_typ_cd in
      ('01', '02', '03', '04', '05', '12', '19',      
       '20', '21', '22', '23', '25', '55', '65', '68')
   and is2.rec_crt_dt < current date
   and pp1.eff_to_dt >= current date
   and (va1.art_nbr_id_cd = upctyp.code
    or  va1.art_nbr_id_cd = 'IH'
   and  is2.sku_typ_cd = '68')
   and  pp1.stat_ind in ('L','A')
)
select * from current_price
 union
select * from future_price
   for fetch only
  with ur
  ;