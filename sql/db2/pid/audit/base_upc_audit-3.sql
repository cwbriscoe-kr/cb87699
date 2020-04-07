drop table mag;
drop table pid;

--create unique index mag_idx_1 on mag (pidcas, pidbas);
--create unique index pid_idx_1 on pid (casupc, basupc);
create unique index mag_idx_1 on mag (sku);
create unique index pid_idx_1 on pid (sku);

drop table report;

create table report as
select mag.sku    as sku
      ,mag.pidcas as magcas
      ,mag.pidbas as magbas
      ,(select '*'
          from pid
         where mag.sku = pid.sku
       ) as sku_exists
      ,(select '*'
          from pid
         where mag.sku    = pid.sku
           and mag.pidcas = pid.casupc
       ) as case_matches
      ,(select '*'
          from pid
         where mag.sku    = pid.sku
           and mag.pidbas = pid.basupc
       ) as base_matches
      ,mag.case_pack as mag_case
      ,(select case_pack
          from pid
         where mag.sku = pid.sku
       ) as pid_case
      ,(select ord_mult
          from pid
         where mag.sku = pid.sku
       ) as pid_ord_mult
  from mag
;

select sku
      ,magcas
      ,magbas
      ,case_matches
      ,base_matches
      ,mag_case
      ,pid_case
      ,pid_ord_mult
  from report
 where sku_exists = '*'
   and (   case_matches isnull
        or base_matches isnull
        or mag_case != pid_case
       )
;

select mag.pidcas as magcas
      ,mag.pidbas as magbas
      ,mag.case_pack as mag_case
      ,(select '*'
          from pid
         where mag.pidcas = pid.casupc
       ) as case_exists
      ,(select '*'
          from pid
         where mag.pidcas = pid.casupc
           and mag.pidbas = pid.basupc
       ) as base_matches
      ,(select case_pack
          from pid
         where mag.pidcas = pid.casupc
       ) as pid_case
      ,(select ord_mult
          from pid
         where mag.pidcas = pid.casupc
       ) as pid_ord_mult
  from mag
-- where mag.pidcas = pid.casupc
--   and mag.pidbas = pid.basupc
;