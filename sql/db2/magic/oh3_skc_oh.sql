select *
  from oh3_skc_oh oso
where sku_nbr = 43425617
  order by perd_fr_dt desc
  with ur;

select *
  from oh3_skc_oh
 where sku_nbr = 00474740
   and loc_nbr = 00065
   --and perd_fr_dt = '2025-06-15'
 order by perd_fr_dt desc
  with ur;

insert into oh3_skc_oh
values(00474740, 65, '2025-06-15', '2025-06-21', 486, 100.0, 100.0, '2025-06-16', 100.0);



--VNDR:   791 0842
--DCID:   00065
--ITEM:   00474740
--LOCA:   00028
--ORDQ:   0000006