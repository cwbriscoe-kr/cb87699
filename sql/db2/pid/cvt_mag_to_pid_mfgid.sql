with mupc as (
  select '00022653576923' as mupc
    from prd.tt1_truth_tbl
),
pupc as (
    select
    mupc
    ,'0'||SUBSTR(CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),1,1)
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),3,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),2,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),4,10),13),2,7)
    as mfgid
    from mupc
)
select * from pupc;

