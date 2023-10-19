select substr(td1.tbl_elem_text,1,5) 
     , td1.tbl_elem_id               
  from prd.td1_tbl_dtl td1               
 where td1.tbl_id = 'K004'           
  with ur 
  ;