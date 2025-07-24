select *
  from li2_po_ln_itm
 where po_id = '000040115251'
  with ur
;

update li2_po_ln_itm
   set alc_method = 'M'
 where po_id = '000040115251'
   and sku_nbr = '91261212'
;
