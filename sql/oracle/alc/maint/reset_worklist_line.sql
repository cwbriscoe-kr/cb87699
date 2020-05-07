select * from worklist where wl_key = 24713890
;

update worklist
  set alloc_nbr = 0
     ,user_id = null
     ,dc_rule_key = null
     ,dc_status_code = null
     ,dc_status_desc = null
     ,dc_status_timestamp = null
     ,dc_rule_info = null
     ,status_code = '10'
     ,status_desc = 'Available'
where wl_key = 24713890 
;