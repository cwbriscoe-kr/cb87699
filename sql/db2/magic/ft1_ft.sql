select *
  from ft1_ft ff
 where lvl06_cd = 95
   and rec_stat_cd = '01'
   and lvl_nbr = 8
   --and lvl08_cd = 985
  with ur
  ;

with sbcom as (
    select lfo_grp_cls_id || lfo_grp_sub_id as sbcom
         ,cast(fam_dpt_cd as decimal) as dpt
         ,cast(fam_cls_cd as decimal) as cls
         ,cast(fam_sbc_cd as decimal) as sbc
    from k26_pid_sbcom
    where fam_dpt_cd > '   '
)
select lvl_nbr as level
      ,lvl04_cd as div
      ,lvl05_cd as dmm
      ,lvl06_cd as dept
      ,lvl07_cd as byr
      ,lvl08_cd as cls
      ,lvl09_cd as scls
      ,coalesce(sbcom.sbcom, 0) as sbcom
      ,desc_lng_txt as description
  from ft1_ft ft left outer join sbcom on (
       ft.lvl06_cd = sbcom.dpt
   and ft.lvl08_cd = sbcom.cls
   and ft.lvl09_cd = sbcom.sbc
      )
 where rec_stat_cd = '01'
   and lvl01_cd = 1
   and lvl02_cd = 1
   and lvl03_cd = 5
   and lvl04_cd != 12
   and lvl09_cd != 9
   and eff_fr_dt <= current_date
   and eff_to_dt >= current_date
 order by lvl_nbr, lvl01_cd, lvl02_cd, lvl03_cd, lvl04_cd, lvl05_cd, lvl06_cd, lvl07_cd, lvl08_cd, lvl09_cd
  with ur;


select *
  from pid_sbcom
 where fam_dpt_cd > '   '
  fetch first 10 rows only
  with ur;

select lfo_grp_cls_id || lfo_grp_sub_id as sbcom
       ,cast(fam_dpt_cd as decimal) as dpt
       ,cast(fam_cls_cd as decimal) as cls
       ,cast(fam_sbc_cd as decimal) as sbc
  from k26_pid_sbcom
where fam_dpt_cd > '   '
 with ur;
