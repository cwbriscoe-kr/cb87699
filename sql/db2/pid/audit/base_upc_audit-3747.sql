drop table mag;
drop table pid;
--run above to drop old data

with skutype as ( 
 select substr(tbl_elem_id,1,2) as code
   from prd.td1_tbl_dtl
  where tbl_id = 'F026' 
    and substr(tbl_elem_text,26,1) = 'Y' 
), 
magbas as (
  select is2.sku_nbr        as sku
        ,sv1.mstr_art_nbr   as magcas
        ,va1.art_nbr        as magbas
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(sv1.mstr_art_nbr),14)),4,10),13) as pidcas
        ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),1,1)
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),3,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),2,1)     
         ||SUBSTR(DIGITS(DECIMAL(RTRIM(va1.art_nbr),14)),4,10),13) as pidbas
        ,coalesce((select sl4.loc_nbr
                    from prd.sl4_sku_loc sl4
                   where sl4.sku_nbr = pie.sku_nbr
                     and sl4.loc_nbr in ('00065','00461')
                     and sl4.rec_stat_cd = '01'
                   order by loc_nbr
                   fetch first 1 row only),'') as whse
        ,is2.rec_stat_cd as sku_sts
        ,is2.sku_typ_cd as sku_typ
    from prd.is2_itm_sku      is2
        ,prd.va1_vndr_art     va1
        ,prd.sv1_sku_vndr_dtl sv1
        ,prd.pie_pid_int_errs pie
        ,skutype
   where pie.sku_nbr            = is2.sku_nbr
     and pie.err_cd             = '03747'
     and va1.sku_nbr            = is2.sku_nbr
     and va1.vndr_nbr           = is2.vndr_nbr
     and va1.sku_nbr            = sv1.sku_nbr
     and va1.vndr_nbr           = sv1.vndr_nbr
     and sv1.prmy_altn_vndr_ind = 'P'
     and is2.sku_typ_cd         = skutype.code
     and va1.bas_arl_fl         = 'B'
     and length(ltrim(rtrim(sv1.mstr_art_nbr))) > 0
     and length(ltrim(rtrim(va1.art_nbr))) > 0
)
select *
  from magbas
  with ur
;
--export above to baseupc.mag

select cas_upc_no as casupc
      ,con_upc_no as basupc
  from prd.pid_casco c1
 where c1.con_typ_cd = '1'
   and row_upd_ts    = (select max(c2.row_upd_ts)
                          from prd.pid_casco c2
                         where c2.cas_upc_no = c1.cas_upc_no
                           and c2.con_upc_no = c2.con_upc_no
                           and c2.con_typ_cd = '1')
  with ur
;
--export above to baseupc.pid

create unique index mag_idx_1 on mag (pidcas);
create unique index pid_idx_1 on pid (casupc);
--create above two indexes

select mag.sku
      ,mag.sku_sts as sts
      ,mag.sku_typ as typ
      ,mag.whse
      ,substr(pid.basupc,1,1)||substr(pid.basupc,3,1)||substr(pid.basupc,2,1)||
       substr(pid.basupc,4,10) as pidbas
  from mag, pid
 where mag.pidcas = pid.casupc
--   and mag.whse = '00065' and mag.sku_sts in ('20','30')
 order by mag.sku
;