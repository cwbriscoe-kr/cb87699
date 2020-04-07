with sku as (
select '02099446' as nbr
  from prd.tt1_truth_tbl
), magwhs as (
select substr(tbl_elem_id,1,5)   as mag_whse
      ,substr(tbl_elem_text,1,3) as pid_whse
  from prd.td1_tbl_dtl
 where tbl_id      = 'K006'
   and org_co_nbr  = '1'
   and org_rgn_nbr = '00'
), pidwhs as (
select is2.sku_nbr
      ,magwhs.mag_whse as mag_whse
      ,coalesce((
       select substr(tbl_elem_text,1,3)
         from prd.td1_tbl_dtl
        where tbl_id      = 'K001'
          and org_co_nbr  = '1'
          and org_rgn_nbr = '00'
          and tbl_elem_id = magwhs.mag_whse ||
              digits(decimal(fi1.ft_lvl06_cd,3))
       ),'???') as src_id
  from prd.is2_itm_sku is2
      ,prd.fi1_ft_itm  fi1
      ,prd.sl4_sku_loc sl4
      ,magwhs, sku
 where is2.sku_nbr     = sku.nbr
   and sl4.sku_nbr     = is2.sku_nbr
   and fi1.itm_nbr     = is2.itm_nbr
   and sl4.loc_nbr     = magwhs.mag_whse
   and sl4.rec_stat_cd = '01'
   and fi1.rec_stat_cd = '01'
), cotbl as (
select substr(tbl_elem_text,22,2) as coid
      ,substr(tbl_elem_id,1,3)    as divcd
  from prd.td1_tbl_dtl
 where tbl_id      = 'K003'
   and org_co_nbr  = '1'
   and org_rgn_nbr = '00'
), divtbl as (
select case ol2.org_co_id
       when '91' then
         case substr(ol2.loc_id,1,2)
         when '20' then
           '620'
         when '40' then
           '706'
         when '50' then
           '705'
         when '60' then
           '703'
         when '61' then
           '615'
         when '70' then
           '660'
         when '25' then
           '023'
         when '91' then
           '701'
         else
           '0' || substr(ol2.loc_id,1,2)
         end
       when '01' then
         case ol2.org_rgn_id
         when '09' then
           case substr(ol2.loc_id,1,2)
           when '40' then
             '706'
           else 
             '701'
           end
         else
           cotbl.divcd
         end
       else
         cotbl.divcd
       end as divcd
  from prd.sl4_sku_loc sl4
      ,prd.ol2_org_loc ol2
      ,cotbl, sku
 where sl4.sku_nbr          = sku.nbr
   and sl4.loc_nbr          = ol2.loc_id
   and sl4.rec_stat_cd      = '01'
   and ol2.org_co_id        = cotbl.coid
   and ol2.loc_type_cd not in ('04','08','09','10','99')
), divs as (
select divcd
  from divtbl
 group by divcd
), srcdivs as (              
select * 
  from pidwhs left outer join divs on 1=1
), data1 as (
select srcdivs.sku_nbr as itm_no
      ,char(substr(digits(decimal(rtrim(               
       sv1.mstr_art_nbr),14)),1,1) ||                  
       substr(digits(decimal(rtrim(                    
       sv1.mstr_art_nbr),14)),3,1) ||                  
       substr(digits(decimal(rtrim(                    
       sv1.mstr_art_nbr),14)),2,1) ||                  
       substr(digits(decimal(rtrim(                    
       sv1.mstr_art_nbr),14)),4,10),13) as cas_upc_no
      ,srcdivs.src_id as src_id
      ,srcdivs.divcd as bil_div_no
      ,'  ' as cat_id
      ,case
       when is2.sku_typ_cd = '55' then
         '00'
       when fi1.ft_lvl06_cd in ('068','079','082','085','089','095') then
         '00'
       else
         '01'
       end as unt_lbl_qy
      ,'A' as div_cas_stu_cd
      ,case
       when srcdivs.divcd = '705'
       and sv1.mdse_flow_cd = 'WHP' then
         space(4)
       when sv1.mdse_flow_cd = 'ALC' then
         'ALOC'
       else
         'FMWR'
       end as div_inf_cd
      ,case
       when is2.sku_typ_cd = '55' then
         'N'
       else
         'S'
       end as qps_scn_cd
  from prd.sv1_sku_vndr_dtl sv1
      ,prd.is2_itm_sku      is2
      ,prd.fi1_ft_itm       fi1
      ,srcdivs
 where sv1.sku_nbr = srcdivs.sku_nbr
   and sv1.prmy_altn_vndr_ind = 'P'
   and is2.sku_nbr = sv1.sku_nbr
   and fi1.itm_nbr = is2.itm_nbr
   and fi1.rec_stat_cd = '01'
), cattbl as (
select substr(tbl_elem_id,1,3)   as srcid
      ,substr(tbl_elem_id,4,3)   as divcd
      ,case substr(tbl_elem_id,7,1)
       when 'A' then
         'ALOC'
       when 'R' then
         'FMWR'
       when 'W' then
         space(4)
       end                       as flowcd
      ,substr(tbl_elem_text,1,2) as id
  from prd.td1_tbl_dtl
 where tbl_id      = 'K002'
   and org_co_nbr  = '1'
   and org_rgn_nbr = '00'
), data2 as (
select cas_upc_no
      ,src_id
      ,bil_div_no
      ,cattbl.id as cat_id
      ,unt_lbl_qy
      ,div_cas_stu_cd
      ,div_inf_cd
      ,qps_scn_cd
  from data1 d
      ,cattbl c
 where d.src_id = c.srcid
   and d.bil_div_no = c.divcd
   and d.div_inf_cd = c.flowcd
)
select * 
  from data2
 order by src_id, bil_div_no
  with ur
;

select cas_upc_no
      ,src_id
      ,bil_div_no
      ,coalesce(cat_id,space(2)) as cat_id
      ,coalesce(unt_lbl_qy,'00') as unt_lbl_qy
      ,coalesce(div_cas_stu_cd,space(1)) as div_cas_stu_cd
      ,coalesce(div_inf_cd,space(4)) as div_inf_cd
      ,coalesce(qps_scn_cd,space(1)) as qps_scn_cd
  from prd.pid_orden
 where cas_upc_no = '1004122645220'
   and src_id in ('791','792','794','797')
 order by src_id, bil_div_no
  with ur
  ;
      