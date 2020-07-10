create or replace PROCEDURE CVT_STG_DIM AS
--backup stage dimension before running just in case
PRAGMA AUTONOMOUS_TRANSACTION;
--script that runs this is scripts/cvtstgdim.sh
BEGIN
BEGIN
  AAMFM.LOGOUTPUT('', 'PROGRAM STARTING');

  AAMFM.LOGOUTPUT('', 'BEGIN TEMP$STAGE_DIMENSION DROP');
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TEMP$STAGE_DIMENSION';
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  AAMFM.LOGOUTPUT('', 'BEGIN TEMP$STAGE_DIMENSION CONVERSION');
  BEGIN
    EXECUTE IMMEDIATE 'CREATE TABLE TEMP$STAGE_DIMENSION NOLOGGING AS ' ||
      'SELECT /*+FULL(stage_dimension) PARALLEL */' ||
      '       LOCATION_ID ' ||
      '      ,DEPT_NBR ' ||
      '      ,SUBDEPT_NBR ' ||
      '      ,CLASS_NBR ' ||
      '      ,ITEM_GROUP_NBR ' ||
      '      ,SUBCLASS_NBR ' ||
      '      ,CHOICE_NBR ' ||
      '      ,STYLE_MASTER_SKU ' ||
      '      ,SKU_NBR ' ||
      '      ,COLOR_NBR ' ||
      '      ,SIZE_NBR ' ||
      '      ,DIM_NBR ' ||
      '      ,STR_ON_ORDER ' ||
      '      ,DNF_INTRANSIT ' ||
      '      ,WTD_SALES ' ||
      '      ,ON_HAND_CURR ' ||
      '      ,ON_HAND_01AGO' ||
      '      ,ON_HAND_02AGO' ||
      '      ,ON_HAND_03AGO' ||
      '      ,ON_HAND_04AGO' ||
      '      ,ON_HAND_05AGO' ||
      '      ,ON_HAND_06AGO' ||
      '      ,ON_HAND_07AGO' ||
      '      ,ON_HAND_08AGO' ||
      '      ,ON_HAND_09AGO' ||
      '      ,ON_HAND_10AGO' ||
      '      ,ON_HAND_11AGO' ||
      '      ,ON_HAND_12AGO' ||
      '      ,ON_HAND_13AGO' ||
      '      ,ON_HAND_14AGO' ||
      '      ,ON_HAND_15AGO' ||
      '      ,ON_HAND_16AGO' ||
      '      ,ON_HAND_17AGO' ||
      '      ,ON_HAND_18AGO' ||
      '      ,ON_HAND_19AGO' ||
      '      ,ON_HAND_20AGO' ||
      '      ,ON_HAND_21AGO' ||
      '      ,ON_HAND_22AGO' ||
      '      ,ON_HAND_23AGO' ||
      '      ,ON_HAND_24AGO' ||
      '      ,ON_HAND_25AGO' ||
      '      ,ON_HAND_26AGO' ||
      '      ,ON_HAND_27AGO' ||
      '      ,ON_HAND_28AGO' ||
      '      ,ON_HAND_29AGO' ||
      '      ,ON_HAND_30AGO' ||
      '      ,ON_HAND_31AGO' ||
      '      ,ON_HAND_32AGO' ||
      '      ,ON_HAND_33AGO' ||
      '      ,ON_HAND_34AGO' ||
      '      ,ON_HAND_35AGO' ||
      '      ,ON_HAND_36AGO' ||
      '      ,ON_HAND_37AGO' ||
      '      ,ON_HAND_38AGO' ||
      '      ,ON_HAND_39AGO' ||
      '      ,ON_HAND_40AGO' ||
      '      ,ON_HAND_41AGO' ||
      '      ,ON_HAND_42AGO' ||
      '      ,ON_HAND_43AGO' ||
      '      ,ON_HAND_44AGO' ||
      '      ,ON_HAND_45AGO' ||
      '      ,ON_HAND_46AGO' ||
      '      ,ON_HAND_47AGO' ||
      '      ,ON_HAND_48AGO' ||
      '      ,ON_HAND_49AGO' ||
      '      ,ON_HAND_50AGO' ||
      '      ,ON_HAND_51AGO' ||
      '      ,ON_HAND_52AGO' ||
      '      ,ON_HAND_53AGO' ||
      '      ,ON_HAND_54AGO' ||
      '      ,ON_HAND_55AGO' ||
      '      ,ON_HAND_56AGO' ||
      '      ,ON_HAND_57AGO' ||
      '      ,ON_HAND_58AGO' ||
      '      ,ON_HAND_59AGO' ||
      '      ,ON_HAND_60AGO' ||
      '      ,ON_HAND_61AGO' ||
      '      ,ON_HAND_62AGO' ||
      '      ,ON_HAND_63AGO' ||
      '      ,ON_HAND_64AGO' ||
      '      ,ON_HAND_65AGO' ||
      '      ,ON_HAND_66AGO' ||
      '      ,ON_HAND_67AGO' ||
      '      ,ON_HAND_68AGO' ||
      '      ,ON_HAND_69AGO' ||
      '      ,ON_HAND_70AGO' ||
      '      ,ON_HAND_71AGO' ||
      '      ,ON_HAND_72AGO' ||
      '      ,ON_HAND_73AGO' ||
      '      ,ON_HAND_74AGO' ||
      '      ,ON_HAND_75AGO' ||
      '      ,ON_HAND_76AGO' ||
      '      ,ON_HAND_77AGO' ||
      '      ,ON_HAND_78AGO' ||
      '      ,0 AS ON_HAND_79AGO' ||
      '      ,0 AS ON_HAND_80AGO' ||
      '      ,0 AS ON_HAND_81AGO' ||
      '      ,0 AS ON_HAND_82AGO' ||
      '      ,0 AS ON_HAND_83AGO' ||
      '      ,0 AS ON_HAND_84AGO' ||
      '      ,0 AS ON_HAND_85AGO' ||
      '      ,0 AS ON_HAND_86AGO' ||
      '      ,0 AS ON_HAND_87AGO' ||
      '      ,0 AS ON_HAND_88AGO' ||
      '      ,0 AS ON_HAND_89AGO' ||
      '      ,0 AS ON_HAND_90AGO' ||
      '      ,0 AS ON_HAND_91AGO' ||
      '      ,0 AS ON_HAND_92AGO' ||
      '      ,0 AS ON_HAND_93AGO' ||
      '      ,0 AS ON_HAND_94AGO' ||
      '      ,0 AS ON_HAND_95AGO' ||
      '      ,0 AS ON_HAND_96AGO' ||
      '      ,0 AS ON_HAND_97AGO' ||
      '      ,0 AS ON_HAND_98AGO' ||
      '      ,0 AS ON_HAND_99AGO' ||
      '      ,0 AS ON_HAND_100AGO' ||
      '      ,0 AS ON_HAND_101AGO' ||
      '      ,0 AS ON_HAND_102AGO' ||
      '      ,0 AS ON_HAND_103AGO' ||
      '      ,0 AS ON_HAND_104AGO' ||
      '      ,SLS_01AGO ' ||
      '      ,SLS_02AGO' ||
      '      ,SLS_03AGO' ||
      '      ,SLS_04AGO' ||
      '      ,SLS_05AGO' ||
      '      ,SLS_06AGO' ||
      '      ,SLS_07AGO' ||
      '      ,SLS_08AGO' ||
      '      ,SLS_09AGO' ||
      '      ,SLS_10AGO' ||
      '      ,SLS_11AGO' ||
      '      ,SLS_12AGO' ||
      '      ,SLS_13AGO' ||
      '      ,SLS_14AGO' ||
      '      ,SLS_15AGO' ||
      '      ,SLS_16AGO' ||
      '      ,SLS_17AGO' ||
      '      ,SLS_18AGO' ||
      '      ,SLS_19AGO' ||
      '      ,SLS_20AGO' ||
      '      ,SLS_21AGO' ||
      '      ,SLS_22AGO' ||
      '      ,SLS_23AGO' ||
      '      ,SLS_24AGO' ||
      '      ,SLS_25AGO' ||
      '      ,SLS_26AGO' ||
      '      ,SLS_27AGO' ||
      '      ,SLS_28AGO' ||
      '      ,SLS_29AGO' ||
      '      ,SLS_30AGO' ||
      '      ,SLS_31AGO' ||
      '      ,SLS_32AGO' ||
      '      ,SLS_33AGO' ||
      '      ,SLS_34AGO' ||
      '      ,SLS_35AGO' ||
      '      ,SLS_36AGO' ||
      '      ,SLS_37AGO' ||
      '      ,SLS_38AGO' ||
      '      ,SLS_39AGO' ||
      '      ,SLS_40AGO' ||
      '      ,SLS_41AGO' ||
      '      ,SLS_42AGO' ||
      '      ,SLS_43AGO' ||
      '      ,SLS_44AGO' ||
      '      ,SLS_45AGO' ||
      '      ,SLS_46AGO' ||
      '      ,SLS_47AGO' ||
      '      ,SLS_48AGO' ||
      '      ,SLS_49AGO' ||
      '      ,SLS_50AGO' ||
      '      ,SLS_51AGO' ||
      '      ,SLS_52AGO' ||
      '      ,SLS_53AGO' ||
      '      ,SLS_54AGO' ||
      '      ,SLS_55AGO' ||
      '      ,SLS_56AGO' ||
      '      ,SLS_57AGO' ||
      '      ,SLS_58AGO' ||
      '      ,SLS_59AGO' ||
      '      ,SLS_60AGO' ||
      '      ,SLS_61AGO' ||
      '      ,SLS_62AGO' ||
      '      ,SLS_63AGO' ||
      '      ,SLS_64AGO' ||
      '      ,SLS_65AGO' ||
      '      ,SLS_66AGO' ||
      '      ,SLS_67AGO' ||
      '      ,SLS_68AGO' ||
      '      ,SLS_69AGO' ||
      '      ,SLS_70AGO' ||
      '      ,SLS_71AGO' ||
      '      ,SLS_72AGO' ||
      '      ,SLS_73AGO' ||
      '      ,SLS_74AGO' ||
      '      ,SLS_75AGO' ||
      '      ,SLS_76AGO' ||
      '      ,SLS_77AGO' ||
      '      ,SLS_78AGO' ||
      '      ,0 AS SLS_79AGO' ||
      '      ,0 AS SLS_80AGO' ||
      '      ,0 AS SLS_81AGO' ||
      '      ,0 AS SLS_82AGO' ||
      '      ,0 AS SLS_83AGO' ||
      '      ,0 AS SLS_84AGO' ||
      '      ,0 AS SLS_85AGO' ||
      '      ,0 AS SLS_86AGO' ||
      '      ,0 AS SLS_87AGO' ||
      '      ,0 AS SLS_88AGO' ||
      '      ,0 AS SLS_89AGO' ||
      '      ,0 AS SLS_90AGO' ||
      '      ,0 AS SLS_91AGO' ||
      '      ,0 AS SLS_92AGO' ||
      '      ,0 AS SLS_93AGO' ||
      '      ,0 AS SLS_94AGO' ||
      '      ,0 AS SLS_95AGO' ||
      '      ,0 AS SLS_96AGO' ||
      '      ,0 AS SLS_97AGO' ||
      '      ,0 AS SLS_98AGO' ||
      '      ,0 AS SLS_99AGO' ||
      '      ,0 AS SLS_100AGO' ||
      '      ,0 AS SLS_101AGO' ||
      '      ,0 AS SLS_102AGO' ||
      '      ,0 AS SLS_103AGO' ||
      '      ,0 AS SLS_104AGO' ||
      '      ,LASTROLL ' ||
      '      ,ATTR_1_CODE' ||
      '      ,ATTR_2_CODE' ||
      '      ,ATTR_3_CODE' ||
      '      ,ATTR_4_CODE' ||
      '      ,ATTR_5_CODE' ||
      '      ,ATTR_6_CODE' ||
      '      ,ATTR_7_CODE' ||
      '      ,ATTR_8_CODE' ||
      '      ,ATTR_9_CODE' ||
      '      ,ATTR_10_CODE' ||
      '      ,ATTR_11_CODE' ||
      '      ,ATTR_12_CODE' ||
      '      ,REG_SLS_WTD' ||
      '      ,REG_SLS_01AGO' ||
      '      ,REG_SLS_02AGO' ||
      '      ,REG_SLS_03AGO' ||
      '      ,REG_SLS_04AGO' ||
      '      ,REG_SLS_05AGO' ||
      '      ,REG_SLS_06AGO' ||
      '      ,REG_SLS_07AGO' ||
      '      ,REG_SLS_08AGO' ||
      '      ,REG_SLS_09AGO' ||
      '      ,REG_SLS_10AGO' ||
      '      ,REG_SLS_11AGO' ||
      '      ,REG_SLS_12AGO' ||
      '      ,REG_SLS_13AGO' ||
      '      ,REG_SLS_14AGO' ||
      '      ,REG_SLS_15AGO' ||
      '      ,REG_SLS_16AGO' ||
      '      ,REG_SLS_17AGO' ||
      '      ,REG_SLS_18AGO' ||
      '      ,REG_SLS_19AGO' ||
      '      ,REG_SLS_20AGO' ||
      '      ,REG_SLS_21AGO' ||
      '      ,REG_SLS_22AGO' ||
      '      ,REG_SLS_23AGO' ||
      '      ,REG_SLS_24AGO' ||
      '      ,REG_SLS_25AGO' ||
      '      ,REG_SLS_26AGO' ||
      '      ,REG_SLS_27AGO' ||
      '      ,REG_SLS_28AGO' ||
      '      ,REG_SLS_29AGO' ||
      '      ,REG_SLS_30AGO' ||
      '      ,REG_SLS_31AGO' ||
      '      ,REG_SLS_32AGO' ||
      '      ,REG_SLS_33AGO' ||
      '      ,REG_SLS_34AGO' ||
      '      ,REG_SLS_35AGO' ||
      '      ,REG_SLS_36AGO' ||
      '      ,REG_SLS_37AGO' ||
      '      ,REG_SLS_38AGO' ||
      '      ,REG_SLS_39AGO' ||
      '      ,REG_SLS_40AGO' ||
      '      ,REG_SLS_41AGO' ||
      '      ,REG_SLS_42AGO' ||
      '      ,REG_SLS_43AGO' ||
      '      ,REG_SLS_44AGO' ||
      '      ,REG_SLS_45AGO' ||
      '      ,REG_SLS_46AGO' ||
      '      ,REG_SLS_47AGO' ||
      '      ,REG_SLS_48AGO' ||
      '      ,REG_SLS_49AGO' ||
      '      ,REG_SLS_50AGO' ||
      '      ,REG_SLS_51AGO' ||
      '      ,REG_SLS_52AGO' ||
      '      ,REG_SLS_53AGO' ||
      '      ,REG_SLS_54AGO' ||
      '      ,REG_SLS_55AGO' ||
      '      ,REG_SLS_56AGO' ||
      '      ,REG_SLS_57AGO' ||
      '      ,REG_SLS_58AGO' ||
      '      ,REG_SLS_59AGO' ||
      '      ,REG_SLS_60AGO' ||
      '      ,REG_SLS_61AGO' ||
      '      ,REG_SLS_62AGO' ||
      '      ,REG_SLS_63AGO' ||
      '      ,REG_SLS_64AGO' ||
      '      ,REG_SLS_65AGO' ||
      '      ,REG_SLS_66AGO' ||
      '      ,REG_SLS_67AGO' ||
      '      ,REG_SLS_68AGO' ||
      '      ,REG_SLS_69AGO' ||
      '      ,REG_SLS_70AGO' ||
      '      ,REG_SLS_71AGO' ||
      '      ,REG_SLS_72AGO' ||
      '      ,REG_SLS_73AGO' ||
      '      ,REG_SLS_74AGO' ||
      '      ,REG_SLS_75AGO' ||
      '      ,REG_SLS_76AGO' ||
      '      ,REG_SLS_77AGO' ||
      '      ,REG_SLS_78AGO' ||
      '      ,0 AS REG_SLS_79AGO' ||
      '      ,0 AS REG_SLS_80AGO' ||
      '      ,0 AS REG_SLS_81AGO' ||
      '      ,0 AS REG_SLS_82AGO' ||
      '      ,0 AS REG_SLS_83AGO' ||
      '      ,0 AS REG_SLS_84AGO' ||
      '      ,0 AS REG_SLS_85AGO' ||
      '      ,0 AS REG_SLS_86AGO' ||
      '      ,0 AS REG_SLS_87AGO' ||
      '      ,0 AS REG_SLS_88AGO' ||
      '      ,0 AS REG_SLS_89AGO' ||
      '      ,0 AS REG_SLS_90AGO' ||
      '      ,0 AS REG_SLS_91AGO' ||
      '      ,0 AS REG_SLS_92AGO' ||
      '      ,0 AS REG_SLS_93AGO' ||
      '      ,0 AS REG_SLS_94AGO' ||
      '      ,0 AS REG_SLS_95AGO' ||
      '      ,0 AS REG_SLS_96AGO' ||
      '      ,0 AS REG_SLS_97AGO' ||
      '      ,0 AS REG_SLS_98AGO' ||
      '      ,0 AS REG_SLS_99AGO' ||
      '      ,0 AS REG_SLS_100AGO' ||
      '      ,0 AS REG_SLS_101AGO' ||
      '      ,0 AS REG_SLS_102AGO' ||
      '      ,0 AS REG_SLS_103AGO' ||
      '      ,0 AS REG_SLS_104AGO' ||
      '  FROM STAGE_DIMENSION';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DELETE INDEX1');
  BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX STAGE_DIMENSION_IDX';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DELETE INDEX2');
  BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX STAGE_DIMENSION_IDX1';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DELETE INDEX3');
  BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX STAGE_DIMENSION_IDX2';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DELETE INDEX4');
  BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX STAGE_DIMENSION_IDX3';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DELETE INDEX5');
  BEGIN
    EXECUTE IMMEDIATE 'DROP INDEX STAGE_DIMENSION_IDX4';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION DROP');
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE STAGE_DIMENSION';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN STAGE_DIMENSION RELOAD');
  BEGIN
    EXECUTE IMMEDIATE('
    CREATE TABLE STAGE_DIMENSION NOLOGGING AS 
    SELECT /*+FULL(TEMP$STAGE_DIMENSION) PARALLEL */ *
    FROM TEMP$STAGE_DIMENSION
    ');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;

  AAMFM.LOGOUTPUT('', 'BEGIN INDEX1 CREATE');
  BEGIN
    EXECUTE IMMEDIATE '
      CREATE INDEX "AAM"."STAGE_DIMENSION_IDX" ON "AAM"."STAGE_DIMENSION" ("LOCATION_ID", "DEPT_NBR", "SUBDEPT_NBR", "CLASS_NBR") 
      PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
      STORAGE(INITIAL 32768 NEXT 32768 MINEXTENTS 1 MAXEXTENTS 2147483645
      PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
      BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
      TABLESPACE "AAMINDEX"   
    ';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;  

  AAMFM.LOGOUTPUT('', 'BEGIN INDEX2 CREATE');
  BEGIN
    EXECUTE IMMEDIATE '
      CREATE INDEX "AAM"."STAGE_DIMENSION_IDX1" ON "AAM"."STAGE_DIMENSION" ("LOCATION_ID", "DEPT_NBR", "SUBDEPT_NBR", "CLASS_NBR", "ITEM_GROUP_NBR", "SUBCLASS_NBR", "CHOICE_NBR", "STYLE_MASTER_SKU", "COLOR_NBR", "SIZE_NBR", "DIM_NBR") 
      PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
      STORAGE(INITIAL 32768 NEXT 32768 MINEXTENTS 1 MAXEXTENTS 2147483645
      PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
      BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
      TABLESPACE "AAMDATA"
    ';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN INDEX3 CREATE');
  BEGIN
    EXECUTE IMMEDIATE '
      CREATE INDEX "AAM"."STAGE_DIMENSION_IDX2" ON "AAM"."STAGE_DIMENSION" ("DEPT_NBR", "SUBDEPT_NBR", "CLASS_NBR", "ITEM_GROUP_NBR") 
      PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
      STORAGE(INITIAL 32768 NEXT 32768 MINEXTENTS 1 MAXEXTENTS 2147483645
      PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
      BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
      TABLESPACE "AAMINDEX"
    ';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN INDEX4 CREATE');
  BEGIN
    EXECUTE IMMEDIATE '
      CREATE UNIQUE INDEX "AAM"."STAGE_DIMENSION_IDX3" ON "AAM"."STAGE_DIMENSION" ("STYLE_MASTER_SKU", "LOCATION_ID") 
      PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
      STORAGE(INITIAL 32768 NEXT 32768 MINEXTENTS 1 MAXEXTENTS 2147483645
      PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
      BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
      TABLESPACE "AAMINDEX"
    ';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN INDEX5 CREATE');
  BEGIN
    EXECUTE IMMEDIATE '
      CREATE UNIQUE INDEX "AAM"."STAGE_DIMENSION_IDX4" ON "AAM"."STAGE_DIMENSION" ("SKU_NBR", "LOCATION_ID") 
      PCTFREE 10 INITRANS 2 MAXTRANS 255 COMPUTE STATISTICS 
      STORAGE(INITIAL 32768 NEXT 32768 MINEXTENTS 1 MAXEXTENTS 2147483645
      PCTINCREASE 0 FREELISTS 1 FREELIST GROUPS 1
      BUFFER_POOL DEFAULT FLASH_CACHE DEFAULT CELL_FLASH_CACHE DEFAULT)
      TABLESPACE "AAMINDEX"
    ';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN GRANTS ON STAGE_DIMENSION');
  BEGIN
    EXECUTE IMMEDIATE 'GRANT UPDATE, INSERT, DELETE, SELECT ON STAGE_DIMENSION TO AAMFM';
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;  
  
  AAMFM.LOGOUTPUT('', 'BEGIN REBUILDSTAGESUBCLASS');
  BEGIN
    ALLOCMMS.REBUILDSTAGESUBCLASS;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN REBUILDSTAGECLASS');
  BEGIN
    ALLOCMMS.REBUILDSTAGECLASS;
  EXCEPTION
    WHEN OTHERS THEN
      RAISE;
  END;
  COMMIT;    

  AAMFM.LOGOUTPUT('', 'BEGIN TEMP$STAGE_DIMENSION DROP');
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE TEMP$STAGE_DIMENSION';
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;

  AAMFM.LOGOUTPUT('', 'PROGRAM ENDING');

EXCEPTION
  WHEN OTHERS THEN
    AAMFM.LOGOUTPUT('',SQLERRM);
    RAISE;
END;
END CVT_STG_DIM;