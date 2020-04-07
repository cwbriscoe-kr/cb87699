with pidft as (
select cast (fam_dpt_cd as integer)     as lvl06
      ,cast (fam_cls_cd as integer)     as lvl08
      ,cast (fam_sbc_cd as integer)     as lvl09
      ,cast ((lfo_grp_cls_id || lfo_grp_sub_id) as char(5))
                                        as sbcom
      ,cast (cpt_com_dsc_tx as char(40))
                                        as desc
  from prd.k26_pid_sbcom
 where fam_dpt_cd between '0001' and '0999'
   and fam_cls_cd between '0001' and '0999'
   and fam_sbc_cd between '0001' and '0999'
),

magft as (
select cast (ft1.lvl06_cd as integer)   as lvl06
      ,cast (ft1.lvl08_cd as integer)   as lvl08
      ,cast (ft1.lvl09_cd as integer)   as lvl09
      ,cast ('XXXXX' as char(5))        as sbcom
      ,cast (ft1.desc_lng_txt  as char(40))
                                        as desc
  from prd.ft1_ft      ft1
 where lvl_nbr          = 9
   and ft1.rec_stat_cd  = '01'
   and ft1.eff_fr_dt   <= current date
   and ft1.eff_to_dt   >  current date
   and ft1.lvl01_cd     = 1
   and ft1.lvl02_cd     = 1
   and ft1.lvl03_cd     = 5
   and ft1.lvl06_cd    != 999
   and ft1.lvl09_cd    != 9
group by ft1.lvl06_cd, ft1.lvl08_cd, ft1.lvl09_cd, 'XXXXX', ft1.desc_lng_txt
),

pidft_1 as (
select 'P' as sys, pidft.* from pidft
),

magft_1 as (
select 'M' as sys, magft.* from magft
),

allft as (
select * from pidft_1 union select * from magft_1
),

notinmag as (
select * 
  from allft t1
 where t1.sys = 'P'
   and not exists 
  (
  select '1'
    from allft t2
   where t2.sys = 'M'
     and t1.lvl06 = t2.lvl06
     and t1.lvl08 = t2.lvl08
     and t1.lvl09 = t2.lvl09
  )
),

notinpid as (
select * 
  from allft t1
 where t1.sys = 'M'
   and not exists 
  (
  select '1'
    from allft t2
   where t2.sys = 'P'
     and t1.lvl06 = t2.lvl06
     and t1.lvl08 = t2.lvl08
     and t1.lvl09 = t2.lvl09
  )
),

combined as (
select * from notinmag
 union
select * from notinpid
),

--select * from combined
--order by sys desc, lvl06, lvl08, lvl09
data as (
select sys
      ,lvl06
      ,lvl08
      ,lvl09
      ,coalesce(
        (select div_subcom_cd
          from prd.ksx_kr_scom_xref
         where fmy_dept_nbr = combined.lvl06
           and fmy_magic_cl_nbr = combined.lvl08
           and fmy_magic_scl_nbr = combined.lvl09
           and eff_fr_dt <= current date
           and eff_to_dt > current date), 'XXXXX') as subcom
      ,desc
  from combined
)

select sys
      ,lvl06
      ,lvl08
      ,lvl09
      ,subcom
      ,desc
  from data
 where sys = 'M'
--   and subcom != 97000
order by sys, lvl06, lvl08, lvl09
;
;
