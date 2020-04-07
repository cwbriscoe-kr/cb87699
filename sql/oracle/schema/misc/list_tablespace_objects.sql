select owner, segment_name , segment_type 
--select *
  from dba_segments
 where tablespace_name = 'USERS'
   and segment_type not in ('LOBINDEX', 'LOBSEGMENT')
   and substr(segment_name,1,3) != 'BIN'
order by segment_name
;