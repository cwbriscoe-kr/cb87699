  select sku_no
        ,count(*) as cnt
    from prd.pid_rmote
group by sku_no   
  having count(*) > 250
;

select sku_nbr
      ,art_bkg_dt
      ,rec_crt_dt
      ,art_nbr
  from prd.va1_vndr_art 
 where sku_nbr in ('09334441','09335141','09551343','09579446','42667841','56615647','70874549')
order by sku_nbr, art_bkg_dt
;