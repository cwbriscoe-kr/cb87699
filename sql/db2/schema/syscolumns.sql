select distinct(name), ColType, Length from Sysibm.syscolumns where tbname = 'LI2_PO_LN_ITM';

with t as (
select colno, name
  from sysibm.syscolumns
 where tbname = 'LI2_PO_LN_ITM'
 order by colno
)
select (select trim(name) from t where colno = 01) || '|' ||
       (select trim(name) from t where colno = 02) || '|' ||
       (select trim(name) from t where colno = 03) || '|' ||
       (select trim(name) from t where colno = 04) || '|' ||
       (select trim(name) from t where colno = 05) || '|' ||
       (select trim(name) from t where colno = 06) || '|' ||
       (select trim(name) from t where colno = 07) || '|' ||
       (select trim(name) from t where colno = 08) || '|' ||
       (select trim(name) from t where colno = 09) || '|' ||
       (select trim(name) from t where colno = 10) || '|' ||
       (select trim(name) from t where colno = 11) || '|' ||
       (select trim(name) from t where colno = 12) || '|' ||
       (select trim(name) from t where colno = 13) || '|' ||
       (select trim(name) from t where colno = 14) || '|' ||
       (select trim(name) from t where colno = 15) || '|' ||
       (select trim(name) from t where colno = 16) || '|' ||
       (select trim(name) from t where colno = 17) || '|' ||
       (select trim(name) from t where colno = 18) || '|' ||
       (select trim(name) from t where colno = 19) || '|' ||
       (select trim(name) from t where colno = 20) || '|' ||
       (select trim(name) from t where colno = 21) || '|' ||
       (select trim(name) from t where colno = 22) || '|' ||
       (select trim(name) from t where colno = 23) || '|' ||
       (select trim(name) from t where colno = 24) || '|' ||
       (select trim(name) from t where colno = 25) || '|' ||
       (select trim(name) from t where colno = 26) || '|' ||
       (select trim(name) from t where colno = 27) || '|' ||
       (select trim(name) from t where colno = 28) || '|' ||
       (select trim(name) from t where colno = 29) || '|' ||
       (select trim(name) from t where colno = 30) || '|' ||
       (select trim(name) from t where colno = 31) || '|' ||
       (select trim(name) from t where colno = 32) || '|' ||
       (select trim(name) from t where colno = 33) || '|' ||
       (select trim(name) from t where colno = 34) || '|' ||
       (select trim(name) from t where colno = 35) || '|' ||
       (select trim(name) from t where colno = 36) || '|' ||
       (select trim(name) from t where colno = 37) || '|' ||
       (select trim(name) from t where colno = 38) || '|' ||
       (select trim(name) from t where colno = 39) || '|' ||
       (select trim(name) from t where colno = 40) || '|' ||
       (select trim(name) from t where colno = 41) || '|' ||
       (select trim(name) from t where colno = 42) || '|' ||
       (select trim(name) from t where colno = 43) || '|' ||
       (select trim(name) from t where colno = 44) || '|' ||
       (select trim(name) from t where colno = 45) || '|' ||
       (select trim(name) from t where colno = 46) || '|' ||
       (select trim(name) from t where colno = 47) || '|' ||
       (select trim(name) from t where colno = 48) || '|' ||
       (select trim(name) from t where colno = 49) || '|' ||
       (select trim(name) from t where colno = 50) || '|' ||
       (select trim(name) from t where colno = 51) || '|' ||
       (select trim(name) from t where colno = 52) || '|' ||
       (select trim(name) from t where colno = 53) || '|' ||
       (select trim(name) from t where colno = 54) || '|' ||
       (select trim(name) from t where colno = 55) || '|' ||
       (select trim(name) from t where colno = 56) || '|' ||
       (select trim(name) from t where colno = 57) || '|' ||
       (select trim(name) from t where colno = 58) || '|' ||
       (select trim(name) from t where colno = 59) || '|' ||
       (select trim(name) from t where colno = 60) || '|' ||
       (select trim(name) from t where colno = 61) as head
  from sysibm.sysdummy1
;