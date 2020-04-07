--first use ftcas connection to drop previous tables
drop table magupc;
drop table pidupc;

--run next two queries with DBP1/DBI1

--export this to ftcas.db table tame magupc
with pan05 as (
  select 'P05'                              as screen 
        ,sv1.mstr_art_nbr                   as mag_upc_no
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13) 
                                            as pid_upc_no
        ,sv1.mstr_art_typ_cd                as cas_upc_typ
        ,digits(decimal(fi1.ft_lvl06_cd,4)) as fam_dpt_cd
        ,digits(decimal(fi1.ft_lvl08_cd,4)) as fam_cls_cd
        ,digits(decimal(fi1.ft_lvl09_cd,4)) as fam_sbc_cd
        ,ksx.div_subcom_cd                  as mag_scom
        ,is2.sku_nbr                        as sku_no
        ,is2.desc_lng_txt                   as desc
    from prd.is2_itm_sku      is2
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.fi1_ft_itm       fi1
        ,prd.sl4_sku_loc      sl4
        ,prd.ksx_kr_scom_xref ksx
   where is2.sku_nbr        = sv1.sku_nbr
     and is2.vndr_nbr       = sv1.vndr_nbr
     and is2.rec_stat_cd   in ('20','30')
     and is2.itm_nbr        = fi1.itm_nbr
     and fi1.rec_stat_cd    = '01'
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
     and sv1.sku_nbr        = sl4.sku_nbr
     and sl4.loc_nbr        = '00065'
     and sl4.rec_stat_cd    = '01'
     and fi1.ft_lvl06_cd    = ksx.fmy_dept_nbr
     and fi1.ft_lvl08_cd    = ksx.fmy_magic_cl_nbr
     and fi1.ft_lvl09_cd    = ksx.fmy_magic_scl_nbr
     and fi1.eff_fr_dt     <= current date
     and fi1.eff_to_dt      > current date
     and ksx.eff_fr_dt     <= current date
     and ksx.eff_to_dt      > current date
),

pan11 as (
  select 'P11'                              as screen 
        ,va1.art_nbr                        as mag_upc_no
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),1,1)
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),3,1)     
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),2,1)     
          ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),4,10),13) 
                                            as pid_upc_no
        ,va1.art_nbr_id_cd                  as cas_upc_typ
        ,digits(decimal(fi1.ft_lvl06_cd,4)) as fam_dpt_cd
        ,digits(decimal(fi1.ft_lvl08_cd,4)) as fam_cls_cd
        ,digits(decimal(fi1.ft_lvl09_cd,4)) as fam_sbc_cd
        ,ksx.div_subcom_cd                  as mag_scom
        ,is2.sku_nbr                        as sku_no
        ,is2.desc_lng_txt                   as desc
    from prd.is2_itm_sku      is2
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.fi1_ft_itm       fi1
        ,prd.va1_vndr_art     va1
        ,prd.sl4_sku_loc      sl4
        ,prd.ksx_kr_scom_xref ksx
   where is2.sku_nbr        = sv1.sku_nbr
     and is2.vndr_nbr       = sv1.vndr_nbr
     and is2.rec_stat_cd   in ('20','30')
     and is2.itm_nbr        = fi1.itm_nbr
     and fi1.rec_stat_cd    = '01'
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
     and sv1.sku_nbr        = va1.sku_nbr
     and sv1.vndr_nbr       = va1.vndr_nbr
     and va1.art_nbr_id_cd in ('CA','CK','CS','CE')
     and length(ltrim(rtrim(va1.art_nbr))) > 0
     and sv1.sku_nbr        = sl4.sku_nbr
     and sl4.loc_nbr        = '00065'
     and sl4.rec_stat_cd    = '01'
     and fi1.ft_lvl06_cd    = ksx.fmy_dept_nbr
     and fi1.ft_lvl08_cd    = ksx.fmy_magic_cl_nbr
     and fi1.ft_lvl09_cd    = ksx.fmy_magic_scl_nbr
     and fi1.eff_fr_dt     <= current date
     and fi1.eff_to_dt      > current date
     and ksx.eff_fr_dt     <= current date
     and ksx.eff_to_dt      > current date
)

select * from pan05
 union
select * from pan11
 order by pid_upc_no
  with ur
;

--export this to ftcas.db table name pidupc
select pdtca.cas_upc_no as pid_upc_no
      ,sbcom.lfo_grp_cls_id || sbcom.lfo_grp_sub_id as subcom
      ,sbcom.fam_dpt_cd
      ,sbcom.fam_cls_cd
      ,sbcom.fam_sbc_cd
      ,sbcom.cpt_dpt_cd
      ,sbcom.cpt_com_cd
  from prd.pid_sbcom sbcom
      ,prd.pid_pdtca pdtca
 where pdtca.lfo_grp_cls_id = sbcom.lfo_grp_cls_id
   and pdtca.lfo_grp_sub_id = sbcom.lfo_grp_sub_id
--   and sbcom.fam_dpt_cd > ' '
--   and sbcom.fam_cls_cd > ' '
--   and sbcom.fam_sbc_cd > ' '
  with ur
;

--now switch connections to ftcas

--add indexes to cas_upc_no on both of the tables we created
create index mag_upc_no on magupc (pid_upc_no);
create unique index pid_upc_no on pidupc (pid_upc_no);

select mupc.fam_dpt_cd  as magic_dept
      ,mupc.fam_cls_cd  as magic_class
      ,mupc.fam_sbc_cd  as magic_subcls
      ,mupc.mag_scom    as magic_scom
      ,mupc.screen      as screen
      ,mupc.sku_no      as sku_nbr
      ,mupc.desc        as description
      ,mupc.mag_upc_no  as magic_upc
      ,mupc.cas_upc_typ as upc_type
      ,pupc.subcom      as pid_subcom
      ,pupc.fam_dpt_cd  as pid_dept
      ,pupc.fam_cls_cd  as pid_class
      ,pupc.fam_sbc_cd  as pid_subcls
      ,pupc.cpt_dpt_cd  as pid_cpt_dpt
      ,pupc.cpt_com_cd  as pid_cpt_com
      ,substr('0000000000000' ||
       substr(pupc.pid_upc_no,1,1) ||
       substr(pupc.pid_upc_no,3,1) ||
       substr(pupc.pid_upc_no,2,1) ||
       substr(pupc.pid_upc_no,4,10),-13,13) as pid_cas_upc
  from magupc mupc
      ,pidupc pupc
 where mupc.pid_upc_no  = pupc.pid_upc_no
  and ((pupc.fam_dpt_cd > '    '
   and (mupc.fam_dpt_cd != pupc.fam_dpt_cd
   or   mupc.fam_cls_cd != pupc.fam_cls_cd
   or   mupc.fam_sbc_cd != pupc.fam_sbc_cd)
  )
   or  mupc.mag_scom != pupc.subcom)
order by magic_dept, magic_class, magic_subcls, sku_no
;