delete
  from aam.plan_format pf
 where not exists (
       select 1
         from aam.worklist wl
        where pf.allocation_nbr = wl.alloc_nbr
 );
 
select count(*) from aam.plan_format
;