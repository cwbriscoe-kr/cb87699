select tbl_elem_id as upc_type
      ,substr(tbl_elem_text,43,1) as send_pid
      ,substr(tbl_elem_text,45,1) as send_pos
  from prd.td1_tbl_dtl
 where tbl_id like 'T013'
   and (substr(tbl_elem_text,45,1) = 'Y'
    or tbl_elem_id in ('CA','CK','CS','CE'))
;