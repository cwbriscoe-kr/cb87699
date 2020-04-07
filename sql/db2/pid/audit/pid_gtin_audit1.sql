select mfg_upc_no as mfgid
      ,case cast(mfr_gtin_cnv_dt as char(10))
         when'0001-01-01' then 'N'
         else 'Y'
       end as gtin
  from prd.pid_mfgid
order by mfg_upc_no;
