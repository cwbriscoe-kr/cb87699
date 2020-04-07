with mupc as (
  select '095636551903' as mupc
    from prd.tt1_truth_tbl
),
pupc as (
    select
    mupc
    ,CHAR(SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),1,1)
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),3,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),2,1)     
    ||SUBSTR(DIGITS(DECIMAL(RTRIM(mupc),14)),4,10),13)
    as pupc
    from mupc
)
select * from pupc;

