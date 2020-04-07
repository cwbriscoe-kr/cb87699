--Like Product interface (Data refresh nightly)
PROCEDURE proc_aallkp (p_bCalledForRebuild    IN BOOLEAN)
IS

   LC_BATCH_COUNT                        CONSTANT PLS_INTEGER  := 10000;
   TYPE    ltyp_arr_level_0            IS TABLE OF LIKE_PRODUCT_MAPPING.LEVEL_0%TYPE         INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_level_1            IS TABLE OF LIKE_PRODUCT_MAPPING.LEVEL_1%TYPE         INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_level_2            IS TABLE OF LIKE_PRODUCT_MAPPING.LEVEL_1%TYPE         INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_like_level_0       IS TABLE OF LIKE_PRODUCT_MAPPING.LIKE_LEVEL_0%TYPE    INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_like_level_1       IS TABLE OF LIKE_PRODUCT_MAPPING.LIKE_LEVEL_1%TYPE    INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_like_level_2       IS TABLE OF LIKE_PRODUCT_MAPPING.LIKE_LEVEL_1%TYPE    INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_use_for_oh         IS TABLE OF LIKE_PRODUCT_MAPPING.USE_FOR_OH%TYPE      INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_rowid              IS TABLE OF ROWID                                     INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_effective_date     IS TABLE OF AALLKP.EFFECTIVE_DATE%TYPE                INDEX BY BINARY_INTEGER;
   TYPE    ltyp_arr_EXPIRATION_DATE    IS TABLE OF AALLKP.EXPIRATION_DATE%TYPE               INDEX BY BINARY_INTEGER;
   
   larr_level_0             ltyp_arr_level_0;
   larr_level_1             ltyp_arr_level_1;
   larr_level_2             ltyp_arr_level_2;
   larr_like_level_0        ltyp_arr_like_level_0;
   larr_like_level_1        ltyp_arr_like_level_1; 
   larr_like_level_2        ltyp_arr_like_level_2;
   larr_use_for_oh          ltyp_arr_use_for_oh;
   larr_effective_date      ltyp_arr_effective_date;
   larr_expiration_date     ltyp_arr_expiration_date;


   TESTSTRING   VARCHAR2 (2000);

   v_arrProcName  VARCHAR2(35)   := 'PROC_AALLKP: ';
   lv_total_inserts        NUMBER := 0;
   lv_cnt                  Number := 0;

   lv_inserts              NUMBER := 0;
   v_sysdate               DATE;



 CURSOR c1 IS
         SELECT EFFECTIVE_DATE,EXPIRATION_DATE,LEVEL_0,LEVEL_1,LEVEL_2,LIKE_LEVEL_0,LIKE_LEVEL_1,LIKE_LEVEL_2,USE_FOR_OH
                FROM aallkp;

BEGIN
 v_sysdate := SYSDATE;

TESTSTRING :='TRUNCATE TABLE LIKE_PRODUCT_MAPPING REUSE STORAGE';
EXECUTE IMMEDIATE TESTSTRING;

LogMesg (v_arrProcname ||'Like Product data load Process Started');

OPEN c1;

  WHILE TRUE
  LOOP
    larr_level_0.DELETE;

    FETCH c1
    BULK COLLECT
    INTO larr_effective_date,larr_expiration_date,
         larr_level_0,larr_level_1,larr_level_2,
         larr_like_level_0,larr_like_level_1,
         larr_Like_level_2 ,larr_use_for_oh
         LIMIT LC_BATCH_COUNT;


   IF larr_level_0.COUNT = 0
   THEN
      EXIT;
   END IF;

   FORALL idx IN 1 .. larr_level_0.count
    INSERT INTO LIKE_PRODUCT_MAPPING
                 (EFFECTIVE_DATE,EXPIRATION_DATE,LEVEL_0,LEVEL_1,LEVEL_2,LIKE_LEVEL_0,LIKE_LEVEL_1,LIKE_LEVEL_2,USE_FOR_OH)
                 VALUES
                 (
                  allocmms.func_is_valid_date (larr_effective_date(idx)),allocmms.func_is_valid_date (larr_expiration_date(idx)),larr_level_0(idx),larr_level_1(idx), larr_level_2(idx),larr_like_level_0(idx),larr_like_level_1(idx), larr_like_level_2(idx), larr_use_for_oh(idx)
                 );
              lv_inserts := lv_inserts + 1;


    LogMesg(v_arrProcname ||'Records Inserted='||lv_Inserts||' of '||LC_BATCH_COUNT);

    COMMIT;

   EXIT WHEN larr_level_0.count < LC_BATCH_COUNT;

   END LOOP;

   CLOSE c1;
    lv_total_inserts := lv_total_inserts + lv_inserts;
    SELECT count(*) into lv_cnt from aallkp;

   LogMesg(v_arrProcname ||'Total Records Inserted='||lv_total_inserts || ' of '|| lv_cnt);
   LogMesg(v_arrProcname ||'Process Complete');
   COMMIT;


EXCEPTION
   WHEN OTHERS
   THEN
      ROLLBACK;
      RAISE;
END proc_aallkp;
--End of like product data load process