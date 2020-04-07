select *
  from prd.pid_pdtco
 where con_upc_no = '0709139043596'
 
fetch first 1000 rows only;

select *
  from prd.pid_pdtco
 where con_upc_no in 
 (
'0600135065462',
'0600135065463',
'0600135065876',
'0600135065877',
'0600135065878',
'0600135065879',
'0600135067695',
'0600135067696',
'0600135067697'
)