select *             
  from prd.td1_tbl_dtl td1               
 where td1.tbl_id = 'F077'
  with ur 
  ;

select *             
  from ACCP.td1_tbl_dtl td1               
 where td1.tbl_id = 'T018'           
  with ur 
  ;

select substr(td1.tbl_elem_text,1,5) 
     , td1.tbl_elem_id               
  from accp.td1_tbl_dtl td1               
 where td1.tbl_id = 'K004'           
  with ur 
  ;
  
select substr(td1.tbl_elem_text,1,5) 
     , td1.tbl_elem_id               
  from accp.td1_tbl_dtl td1               
 where td1.tbl_id = 'T013'           
  with ur 
  ;
                   