--Model data load process Modified on 12/19/2019
PROCEDURE proc_aalmod(p_bCalledForRebuild    IN BOOLEAN)
IS

BEGIN
    LogMesg('proc_aalmod: Start');

    -- Inserting / Updating Model data
    LogMesg('Proc_aalmod_data: Calling proc_aalmod_data');
    allocmms.proc_aalmod_data;
     
   LogMesg('proc_modelassign: Calling proc_modelassign');
   allocmms.PROC_MODELASSIGN;
   LogMesg('proc_modelassign: End of proc_modelassign');
    
    LogMesg('Proc_aalmod: Process Complete');

EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        LogError ('proc_aalmod', SQLERRM, SQLCODE, 0);
        RAISE;
END proc_aalmod;

---Model Data Load
PROCEDURE proc_aalmod_data
IS

   LC_BATCH_COUNT                        CONSTANT PLS_INTEGER  := 10000;
   TYPE    ltyp_arr_model_name            IS TABLE OF MD$IMPORT_DATA.MODEL_NAME%TYPE         INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_LEVEL_1               IS TABLE OF MD$IMPORT_DATA.LEVEL_1%TYPE            INDEX BY BINARY_INTEGER; 
   TYPE    ltyp_arr_LEVEL_2               IS TABLE OF MD$IMPORT_DATA.LEVEL_2%TYPE            INDEX BY BINARY_INTEGER; 
   TYPE    ltyp_arr_LEVEL_3               IS TABLE OF MD$IMPORT_DATA.LEVEL_3%TYPE            INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_LEVEL_4               IS TABLE OF MD$IMPORT_DATA.LEVEL_4%TYPE            INDEX BY BINARY_INTEGER; 
   TYPE    ltyp_arr_LEVEL_5               IS TABLE OF MD$IMPORT_DATA.LEVEL_5%TYPE            INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_LOCATION_ID           IS TABLE OF MD$IMPORT_DATA.LOCATION_ID%TYPE        INDEX BY BINARY_INTEGER; 
   TYPE    ltyp_arr_THRESHOLD             IS TABLE OF MD$IMPORT_DATA.THRESHOLD%TYPE          INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_TARGET                IS TABLE OF MD$IMPORT_DATA.TARGET%TYPE             INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_SIZE_RATIO            IS TABLE OF MD$IMPORT_DATA.SIZE_RATIO%TYPE         INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_MINIMUM               IS TABLE OF MD$IMPORT_DATA.MINIMUM%TYPE            INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_MAXIMUM               IS TABLE OF MD$IMPORT_DATA.MAXIMUM%TYPE            INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_VIEW_ID               IS TABLE OF MD$IMPORT_DATA.VIEW_ID%TYPE            INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_rowid                 IS TABLE OF ROWID                                  INDEX BY BINARY_INTEGER;

   larr_model_name          ltyp_arr_model_name;
   larr_level_1             ltyp_arr_level_1;
   larr_level_2             ltyp_arr_level_2;
   larr_level_3             ltyp_arr_level_3;
   larr_level_4             ltyp_arr_level_4;
   larr_level_5             ltyp_arr_level_5;
   larr_location_id         ltyp_arr_location_id;
   larr_threshold           ltyp_arr_threshold;
   larr_target              ltyp_arr_target;
   larr_size_ratio          ltyp_arr_size_ratio;
   larr_minimum             ltyp_arr_minimum;
   larr_maximum             ltyp_arr_maximum;
   larr_view_id             ltyp_arr_view_id;

   TESTSTRING   VARCHAR2 (2000);

   v_arrProcName  VARCHAR2(35)   := 'PROC_AALMOD_DATA: ';
   lv_total_inserts        NUMBER := 0;
   lv_cnt                  Number := 0;

   lv_inserts              NUMBER := 0;
   v_sysdate               DATE;
   
   TESTSTRING1             VARCHAR2 (2000);
   TESTSTRING2             VARCHAR2 (2000);


 CURSOR c1 IS
         SELECT   MODEL_NAME,
                  LEVEL_1,                                    
                  LEVEL_2,                                     
                  LEVEL_3,                                     
                  LEVEL_4,                                     
                  LEVEL_5,                                     
                  LOCATION_ID,                                     
                  THRESHOLD,                                     
                  TARGET,                                     
                  SIZE_RATIO,                                     
                  MINIMUM,                                     
                  MAXIMUM,                                  
                  VIEW_ID 
                FROM aalmod;

BEGIN
 v_sysdate := SYSDATE;

TESTSTRING1 :='TRUNCATE TABLE MD$IMPORT_DATA REUSE STORAGE';
EXECUTE IMMEDIATE TESTSTRING1;
TESTSTRING2 := 'DELETE MD$NAMES';
EXECUTE IMMEDIATE TESTSTRING2;
COMMIT;

LogMesg (v_arrProcname ||'Started');

OPEN c1;

  WHILE TRUE
  LOOP
    larr_location_id.DELETE;

    FETCH c1
    BULK COLLECT
    INTO larr_model_name,
         larr_level_1,
         larr_level_2,
         larr_level_3,
         larr_level_4,
         larr_level_5,
         larr_location_id,
         larr_threshold,
         larr_target,
         larr_size_ratio,
         larr_minimum,
         larr_maximum,
         larr_view_id
         LIMIT LC_BATCH_COUNT;


   IF larr_location_id.COUNT = 0
   THEN
      EXIT;
   END IF;

   FORALL idx IN 1 .. larr_location_id.count
    INSERT INTO MD$IMPORT_DATA
                (MODEL_NAME,LEVEL_1,LEVEL_2,LEVEL_3,LEVEL_4,LEVEL_5,LOCATION_ID,THRESHOLD,TARGET,SIZE_RATIO,MINIMUM,MAXIMUM,VIEW_ID)
                 VALUES
                 (
                     larr_model_name(idx),larr_level_1(idx),larr_level_2(idx),larr_level_3(idx),larr_level_4(idx),larr_level_5(idx),larr_location_id (idx),
                     larr_threshold (idx), larr_target (idx), larr_size_ratio (idx), larr_minimum (idx),larr_maximum (idx),larr_view_id (idx)
                 );
              lv_inserts := lv_inserts + 1;



       lv_total_inserts := lv_total_inserts + lv_inserts;

    LogMesg(v_arrProcname ||'Records Inserted='||lv_Inserts||' of '||LC_BATCH_COUNT);

    COMMIT;

   EXIT WHEN larr_location_id.count < LC_BATCH_COUNT;

   END LOOP;

   CLOSE c1;
    lv_total_inserts := lv_total_inserts + lv_inserts;
    SELECT count(*) into lv_cnt from aalmod;

   LogMesg(v_arrProcname ||'Total Records Inserted='||lv_total_inserts || ' of '|| lv_cnt);
   LogMesg(v_arrProcname ||'Process Complete');
   COMMIT;
  

 COMMIT;
  --Initialize the model key sequence
    EXECUTE IMMEDIATE 'DROP SEQUENCE NEXT_MODELKEY';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE NEXT_MODELKEY '||
                       'START WITH 1 ' ||
                       'MAXVALUE 2000000000 ' ||
                       'MINVALUE 1 ' ||
                       'CYCLE ' ||
                       'CACHE 20 ' ||
                       'NOORDER';

   AllocModels.UpdateImportData (FALSE);
   COMMIT;

EXCEPTION
   WHEN OTHERS
   THEN
      ROLLBACK;
      RAISE;
END proc_aalmod_data;
--End of Model data load process

--Assign Models to products procedure
PROCEDURE PROC_MODELASSIGN AS
PRAGMA AUTONOMOUS_TRANSACTION;

CURSOR cur_model IS
        SELECT   model_name
          FROM    AALMOD
          GROUP BY MODEL_NAME;


    lv_md_cleanup  VARCHAR2(50);
BEGIN
FOR curr_rec IN cur_model LOOP
     Lv_md_cleanup := AllocModels.AssignModelToProduct(curr_rec.model_name,curr_rec.model_name);
    END LOOP;

    COMMIT;
END PROC_MODELASSIGN;
---- End of model product assignment procedure