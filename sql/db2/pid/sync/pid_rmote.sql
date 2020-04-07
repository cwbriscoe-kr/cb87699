select cas_upc_no	 
      ,con_upc_no
      ,sys_id
      ,itm_no
      ,itm_dsc_tx
      ,stu_cd
      ,fam_dpt_cd
      ,fam_cls_cd
      ,fam_sbc_cd
      ,cas_shp_fl
      ,itm_abb_dsc_tx
      ,shp_pak_qy
      ,con_typ_cd
      ,con_dsc_abb_tx
      ,sku_no
      ,siz_uom_cd
      ,CASE 
       WHEN SKU_NO = '13157340' THEN 
         CASE 
         WHEN (DAYS(CURRENT TIMESTAMP) - DAYS(ROW_UPD_TS)) > 30 THEN 
           'Y' 
         ELSE 
           'N' 
         END 
       ELSE 
         'Y' 
       END as flag
    from accp.pid_rmote
   where sku_no = '13157340'
--      or ( 
--              cas_upc_no = '0400000044844'
--          and sku_no != '23367418'
--         )
order by cas_upc_no, con_upc_no, sys_id
fetch first 1000 rows only;

select *
  from prd.pid_rmote
 where row_upd_ts = '2000-01-01-00.00.00.000000'
 with ur;
