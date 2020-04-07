--drop old tables
drop table mag_mfgid;
drop table pid_mfgid;

--create index for faster results
create unique index pid_mfgid_idx on pid_mfgid (MFGID);

--UPC LEVEL
select substr(mfgid,1,1) || substr(mfgid,3,1) || 
       substr(mfgid,2,1) || substr(mfgid,4,5) as mfgid
      ,vndr_nm
      ,sku
      ,mupc
  from mag_mfgid
 where mfgid not in (
  select mfgid
    from pid_mfgid
  )
 order by mfgid, sku
;

--VNDR LVL
select substr(mfgid,1,1) || substr(mfgid,3,1) || 
       substr(mfgid,2,1) || substr(mfgid,4,5) as mfgid
      ,substr(pupc,1,1) || substr(pupc,3,1) || 
       substr(pupc,2,1) || substr(pupc,4,10)  as case_upc
      ,mag_mfgid.vndr_nm
      ,mag_mfgid.sku
  from mag_mfgid
 where mfgid not in (
  select mfgid
    from pid_mfgid
  )
 group by mag_mfgid.mfgid
 order by mfgid
;
