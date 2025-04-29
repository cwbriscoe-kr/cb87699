select *             
  from prd.td1_tbl_dtl td1               
 where td1.tbl_id = 'R005'
 order by tbl_elem_id
  with ur 
  ;

select *             
  from accp.td1_tbl_dtl td1
 where td1.tbl_id = 'T025'
  with ur 
  ;

select substr(td1.tbl_elem_text,1,5) 
     , td1.tbl_elem_id               
  from prd.td1_tbl_dtl td1
 where td1.tbl_id = 'K004'           
  with ur 
  ;
  
select substr(td1.tbl_elem_text,1,5) 
     , td1.tbl_elem_id               
  from accp.td1_tbl_dtl td1               
 where td1.tbl_id = 'T025'
  with ur 
  ;

insert into accp.td1_tbl_dtl
values ('T025','1','00','2020A11','','2020-04-18 3 4 3 P03 SPRING SEASON  03 2020-04-12           ')
;
