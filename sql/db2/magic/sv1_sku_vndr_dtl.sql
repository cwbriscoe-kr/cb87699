select *
  from prd.sv1_sku_vndr_dtl
 where vndr_nbr = '38221800'
   and sku_nbr = '61754744'
  with ur 
  ;
  
select sku_nbr
      ,vndr_nbr
      ,buy_unt
      ,buy_uom
      ,case_pack_qty
      ,inner_pack_qty
  from prd.sv1_sku_vndr_dtl
 where vndr_nbr = '38221800'
   and sku_nbr = '61754744'
  with ur 
  ;
  