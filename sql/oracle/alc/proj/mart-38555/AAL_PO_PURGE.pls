create or replace PROCEDURE AAL_PO_PURGE AS 
PURGE_ENABLED AAM_PARAMETERS.PARAMETER_VALUE%type;
PURGE_DAYS NUMBER;
BEGIN

update dq_status
   set status_desc = '1 started'
      ,rec_alt_ts  = systimestamp;
commit;

--See if purge is enabled, if not return
begin
  select parameter_value
    into PURGE_ENABLED
    from aam_parameters
   where parameter_type = 'PURGE_PROCEDURE'
     and parameter_code = 'ENABLED';
end;

if PURGE_ENABLED != 'Y' then
  update dq_status
     set status_desc = 'PURGE NOT ENABLED.  PURGE PROCESS ABORTED.'
        ,rec_alt_ts  = systimestamp;
  commit;
  return;
end if;

--Retrieve how many days to keep old WL lines
begin
  select TO_NUMBER(TRIM(COALESCE(parameter_value,'45')))
    into PURGE_DAYS
    from aam_parameters
   where parameter_type = 'PURGE_PROCEDURE'
     and parameter_code = 'RESULTS_AGE_DAYS';
end;

if PURGE_DAYS < 14 then
  PURGE_DAYS := 14;
end if;

-- Delete any po's that exist in arthur and have been fully supplied or 
-- cancelled.
begin
  execute immediate 'DROP TABLE wl_purge_a';
  exception
    when others then null;
end;
execute immediate 'CREATE TABLE wl_purge_a nologging tablespace AAMDATA AS '||
 'select po_nbr, MAX(status_timestamp) as status_timestamp ' ||
   'from worklist ' ||
       ',TC2_PO_TRM_COND tc2 ' ||
  'where tc2.po_id = ''00'' || po_nbr ' ||
    'and tc2.po_stat_cd in (''FS'', ''CX'', ''OX'', ''PX'') ' ||
  'group by po_nbr ' ||
  'order by po_nbr ';
 
update dq_status
   set status_desc = '2 wl_purge_a created'
      ,rec_alt_ts  = systimestamp;
commit; 

--Get all worklist keys from the worklist table where PO_ID in wl_purge_a
begin
  execute immediate 'DROP TABLE wl_purge_list';
  exception
    when others then null;
end;
execute immediate 'CREATE TABLE wl_purge_list nologging tablespace AAMDATA as ' ||
 'select wl.wl_key, wl.alloc_nbr ' ||
   'from worklist wl ' ||
       ',wl_purge_a pa ' ||
 'where wl.po_nbr = pa.po_nbr ' ||
   'and wl.status_code in (''10'', ''30'', ''50'') ' ||
   'and wl.status_timestamp < (sysdate-' || TO_CHAR(PURGE_DAYS) || ') ' ||
 'order by wl.wl_key';
 
update dq_status
   set status_desc = '3 wl_purge_list created'
      ,rec_alt_ts  = systimestamp;
commit;

--Get a list of all unique po numbers in the worklist
begin
  execute immediate 'DROP TABLE wl_purge_b';
  exception
    when others then null;
end;
execute immediate 'CREATE TABLE wl_purge_b nologging tablespace AAMDATA as ' ||
 'with polist as ( ' ||
           'select po_nbr, MAX(status_timestamp) as status_timestamp ' ||
           '  from worklist ' ||
           'group by po_nbr ' ||
           'order by po_nbr ' ||
 ') ' ||
 'select po_nbr ' ||
   'from polist ' ||
  'where status_timestamp < (sysdate-' || TO_CHAR(PURGE_DAYS) || ') ' ||
    'and length(trim(po_nbr)) > 5 ' ||
 'order by po_nbr ';
 
update dq_status
   set status_desc = '4 wl_purge_b created'
      ,rec_alt_ts  = systimestamp;
commit; 

--Get a list of worklist po numbers that do not exist in magic
begin
  execute immediate 'DROP TABLE wl_purge_c';
  exception
    when others then null;
end;
execute immediate 'CREATE TABLE wl_purge_c nologging tablespace AAMDATA as ' ||
 'with polist as ( ' ||
      'select pb.po_nbr, tc2.po_id '||
       'from wl_purge_b pb left outer join ' ||
            'tc2_po_trm_cond tc2 ' ||
         'on ((''00'' || pb.po_nbr) = tc2.po_id) ' ||
 ') ' ||
 'select po_nbr ' ||
   'from polist ' ||
  'where po_id is null ' ||
  'order by po_nbr ';
 
update dq_status
   set status_desc = '5 wl_purge_c created'
      ,rec_alt_ts  = systimestamp;
commit; 

--Now add the list to the purge list
execute immediate 'INSERT INTO wl_purge_list ' ||
 'select wl.wl_key, wl.alloc_nbr ' ||
   'from worklist wl ' ||
       ',wl_purge_c pc ' ||
 'where wl.po_nbr = pc.po_nbr ' ||
 'order by wl.wl_key';
 
update dq_status
   set status_desc = '6 wl_purge_list_1 inserted'
      ,rec_alt_ts  = systimestamp;
commit;

--Purge status level 40's that have expired
execute immediate 'INSERT INTO wl_purge_list ' ||
 'select wl.wl_key, wl.alloc_nbr ' ||
   'from worklist wl ' ||
 'where wl.status_code = ''40'' ' ||
 '  and wl.status_timestamp < (sysdate-' || TO_CHAR(PURGE_DAYS) || ') ' ||
 'order by wl.wl_key';
 
update dq_status
   set status_desc = '7 wl_purge_list_2 inserted'
      ,rec_alt_ts  = systimestamp;
commit;

--Roll worklist backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_wklist7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist6 rename to wl_purge_bkup_wklist7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist5 rename to wl_purge_bkup_wklist6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist4 rename to wl_purge_bkup_wklist5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist3 rename to wl_purge_bkup_wklist4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist2 rename to wl_purge_bkup_wklist3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_wklist1 rename to wl_purge_bkup_wklist2';
  exception when others then null;
end;

--Roll results header backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_rheader7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader6 rename to wl_purge_bkup_rheader7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader5 rename to wl_purge_bkup_rheader6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader4 rename to wl_purge_bkup_rheader5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader3 rename to wl_purge_bkup_rheader4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader2 rename to wl_purge_bkup_rheader3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rheader1 rename to wl_purge_bkup_rheader2';
  exception when others then null;
end;

--Roll results detail backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_rdetail7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail6 rename to wl_purge_bkup_rdetail7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail5 rename to wl_purge_bkup_rdetail6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail4 rename to wl_purge_bkup_rdetail5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail3 rename to wl_purge_bkup_rdetail4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail2 rename to wl_purge_bkup_rdetail3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_rdetail1 rename to wl_purge_bkup_rdetail2';
  exception when others then null;
end;

--Roll actual format backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_aformat7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat6 rename to wl_purge_bkup_aformat7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat5 rename to wl_purge_bkup_aformat6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat4 rename to wl_purge_bkup_aformat5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat3 rename to wl_purge_bkup_aformat4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat2 rename to wl_purge_bkup_aformat3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_aformat1 rename to wl_purge_bkup_aformat2';
  exception when others then null;
end;

--Roll pack_style backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_pstyle7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle6 rename to wl_purge_bkup_pstyle7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle5 rename to wl_purge_bkup_pstyle6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle4 rename to wl_purge_bkup_pstyle5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle3 rename to wl_purge_bkup_pstyle4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle2 rename to wl_purge_bkup_pstyle3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pstyle1 rename to wl_purge_bkup_pstyle2';
  exception when others then null;
end;


--Roll plan_format backups (7-days worth)
begin
  execute immediate 'drop table wl_purge_bkup_pformat7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat6 rename to wl_purge_bkup_pformat7';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat5 rename to wl_purge_bkup_pformat6';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat4 rename to wl_purge_bkup_pformat5';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat3 rename to wl_purge_bkup_pformat4';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat2 rename to wl_purge_bkup_pformat3';
  exception when others then null;
end;
begin
  execute immediate 'alter table wl_purge_bkup_pformat1 rename to wl_purge_bkup_pformat2';
  exception when others then null;
end;

update dq_status
   set status_desc = '8 wl_purge_bkup_roll'
      ,rec_alt_ts  = systimestamp;
commit; 

--Create backup of the worklist lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_wklist1 nologging tablespace AAMDATA as ' ||
 'select wl.* ' ||
   'from worklist wl ' ||
       ',wl_purge_list pb ' ||
 'where wl.wl_key = pb.wl_key ' ||
 'order by pb.wl_key';

--Create backup of the results_header lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_rheader1 nologging tablespace AAMDATA as ' ||
 'select rh.ALLOCATION_NBR ' ||
       ',rh.SAVED_NAME ' ||
       ',rh.SAVED_DESC ' ||
       ',rh.USER_ID ' ||
       ',rh.AAM_CREATEUSER ' ||
       ',rh.GLOBAL_FLAG ' ||
       ',rh.PLANNING_TIMECODE ' ||
       ',rh.CREATEUSER ' ||
       ',rh.CREATEDATE ' ||
       ',rh.UPDATEUSER ' ||
       ',rh.UPDATEDATE ' ||
--Next column is skipped because oracle does not allow CREATE TABLE SELECT AS when
--one of the columns is defined as "LONG".  Also apparently the LONG datatype
--is a string?!?!?!?!?  Every programming language I have ever seen, the LONG
--data type is numeric but Oracle decided, "Hey, I know, lets make the LONG 
--datatype a string to really mess with people's minds.  Far out man....."
--     'rh.ENV_INFORMATION ' ||
   'from results_header rh ' ||
       ',wl_purge_list pb ' ||
 'where rh.allocation_nbr = pb.alloc_nbr ' ||
   'and pb.alloc_nbr > 0 ' ||
 'order by rh.allocation_nbr';
 
--Create backup of the results_detail lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_rdetail1 nologging tablespace AAMDATA as ' ||
 'select rd.* ' ||
   'from results_detail rd ' ||
       ',wl_purge_list pb ' ||
 'where rd.allocation_nbr = pb.alloc_nbr ' ||
   'and pb.alloc_nbr > 0 ' ||
 'order by rd.allocation_nbr';

--Create backup of the results_detail lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_aformat1 nologging tablespace AAMDATA as ' ||
 'select af.* ' ||
   'from actual_format af ' ||
       ',wl_purge_list pb ' ||
 'where af.alloc_nbr = pb.alloc_nbr ' ||
   'and pb.alloc_nbr > 0 ' ||
 'order by af.alloc_nbr';
 
--Create backup of the pack_style lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_pstyle1 nologging tablespace AAMDATA as ' ||
 'select ps.* ' ||
   'from pack_style ps ' ||
       ',wl_purge_list pb ' ||
 'where ps.wl_key = pb.wl_key ' ||
 'order by ps.wl_key';

--Create backup of the plan_format lines we are going to delete
execute immediate 'CREATE TABLE wl_purge_bkup_pformat1 nologging tablespace AAMDATA as ' ||
 'select pf.* ' ||
   'from pack_format pf ' ||
   'where not exists ( ' ||
       'select 1 ' ||
         'from worklist wl ' ||
        'where pf.allocation_nbr = wl.alloc_nbr) ';
 
update dq_status
   set status_desc = '9 wl_purge_bkup_create'
      ,rec_alt_ts  = systimestamp;
commit; 

--Now do the deletes, rollback if any fail
BEGIN

  BEGIN
    DELETE
      FROM WORKLIST
     WHERE WL_KEY IN 
                    (SELECT WL_KEY
                       FROM WL_PURGE_LIST);
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;
  
--Deletes to RESULTS_HEADER will be cascaded to the RESULTS_DETAIL table
  BEGIN
    DELETE
      FROM RESULTS_HEADER
     WHERE ALLOCATION_NBR IN 
                    (SELECT ALLOC_NBR
                       FROM WL_PURGE_LIST
                      WHERE ALLOC_NBR > 0);
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;
  
  BEGIN
    DELETE
      FROM ACTUAL_FORMAT
     WHERE ALLOC_NBR IN 
                    (SELECT ALLOC_NBR
                       FROM WL_PURGE_LIST
                      WHERE ALLOC_NBR > 0);
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;
  
  BEGIN
    DELETE
      FROM PACK_STYLE
     WHERE WL_KEY IN 
                    (SELECT WL_KEY
                       FROM WL_PURGE_LIST);
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;
  
  BEGIN
    DELETE
      FROM  PLAN_FORMAT PF
     WHERE NOT EXISTS (
           SELECT 1
             FROM WORKLIST WL
            WHERE PF.ALLOCATION_NBR = WL.ALLOC_NBR);            
    EXCEPTION WHEN NO_DATA_FOUND THEN NULL;
  END;
  
  --No errors
  update dq_status
   set status_desc = '10 wl_dlt_wklist'
      ,rec_alt_ts  = systimestamp;
  commit; 
  
  --Errors
  EXCEPTION WHEN OTHERS THEN
    ROLLBACK;
    update dq_status
       set status_desc = '10 delete_failed'
           ,rec_alt_ts  = systimestamp;
    commit; 
END;

EXCEPTION WHEN NO_DATA_FOUND THEN NULL;

END AAL_PO_PURGE;