create or replace PACKAGE BODY                     "ALLOCMMS" AS

TYPE t_rCursor 		IS REF CURSOR;
TYPE t_FieldNames	IS TABLE OF VARCHAR2(200) INDEX BY BINARY_INTEGER;
TYPE t_SeqNumbers IS TABLE OF NUMBER INDEX BY BINARY_INTEGER;

v_CRLF		   	  CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);
v_LF			  CONSTANT VARCHAR2(1) := CHR(10);
v_CR			  CONSTANT VARCHAR2(1) := CHR(13);

-- These are the alternate table names for STAGE_DIMENSION and STAGE_SUBCLASS tables.
OLD_STAGE_DIMENSION_TABLE_NAME   CONSTANT VARCHAR2(19) := 'OLD$STAGE_DIMENSION';
OLD_STAGE_SUBCLASS_TABLE_NAME    CONSTANT VARCHAR2(18) := 'OLD$STAGE_SUBCLASS';
OLD_STAGE_CLASS_TABLE_NAME       CONSTANT VARCHAR2(18) := 'OLD$STAGE_CLASS';

-- This variable holds all the names of the shape tables that coorespond to the
-- st_% variables declared below. It is also indexed by these values. You shouldn't
-- have much reason to change any of these values.
g_ListShapeTable	AllocMMS.t_FieldNamesArray;

-- These variables are 0 indexed tables of numbers. The item at level 0 represents the
-- shape type for style, while 1 represents the shape type for color, etc.
g_stPack	t_SeqNumbers;	-- Shape types for Pack.

-- No const% variable declared below should ever be changed!
-- Doing so will cause Allocation to not work well.
const_available_to_allocate	      CONSTANT PLS_INTEGER := 10;
const_in_progress			            CONSTANT PLS_INTEGER := 20;
const_descrepancy			            CONSTANT PLS_INTEGER := 25;
const_approved				            CONSTANT PLS_INTEGER := 30;
const_released				            CONSTANT PLS_INTEGER := 40;
const_unapproved			            CONSTANT PLS_INTEGER := 50;
-- (not currently used) const_error_writing_results	      CONSTANT PLS_INTEGER := 60;
-- (not currently used) const_failed_to_allocate	        CONSTANT PLS_INTEGER := 70;
-- (not currently used) const_locked				              CONSTANT PLS_INTEGER := 99;

const_dimension_shape CONSTANT PLS_INTEGER := 1;
const_size_shape      CONSTANT PLS_INTEGER := 2;
const_color_shape CONSTANT PLS_INTEGER := 3;
const_style_shape     CONSTANT PLS_INTEGER := 4;
-- This is the hard-coded product dimension.
c_ProductDim	CONSTANT PLS_INTEGER := 1;


/************************************************************************
 * Local helper functions...											*
 ************************************************************************/

-- Returns TRUE if a table exists
FUNCTION TableExists(tableName VARCHAR2) RETURN BOOLEAN AS
         tableFound PLS_INTEGER;
BEGIN
  SELECT count(*) INTO tableFound
  FROM user_tables u
  WHERE UPPER(u.table_name) = tableName;

  RETURN tableFound <> 0;
END TableExists;

--
-- Gets extent information.
--
--FUNCTION GetExtentInfo( tableName VARCHAR2, initialExtent OUT PLS_INTEGER, nextExtent OUT PLS_INTEGER, minExtent OUT PLS_INTEGER, maxExtent OUT PLS_INTEGER, pctIncrease OUT PLS_INTEGER ) RETURN BOOLEAN AS
--BEGIN
--     SELECT t.initial_extent,
--            t.next_extent,
--            t.min_extents,
--            t.max_extents,
--            t.pct_increase
--     INTO initialExtent , nextExtent, minExtent, maxExtent, pctIncrease
--     FROM user_tables t
--     WHERE upper(t.table_name) = upper(tableName);
--
--     RETURN TRUE;
--EXCEPTION
--         WHEN OTHERS THEN
--         RETURN FALSE;
--END GetExtentInfo;

FUNCTION GetExtentInfo(
tableName VARCHAR2,
initialExtent OUT user_tables.initial_extent%TYPE,
nextExtent  OUT user_tables.next_extent%TYPE,
minExtent   OUT user_tables.min_extents%TYPE,
maxExtent   OUT user_tables.max_extents%TYPE,
pctIncrease OUT user_tables.pct_increase%TYPE
)
RETURN BOOLEAN AS
BEGIN
     SELECT t.initial_extent,
            t.next_extent,
            t.min_extents,
            t.max_extents,
            t.pct_increase
     INTO initialExtent , nextExtent, minExtent, maxExtent, pctIncrease
     FROM user_tables t
     WHERE upper(t.table_name) = upper(tableName);

     RETURN TRUE;
EXCEPTION
         WHEN OTHERS THEN
         RETURN FALSE;
END GetExtentInfo;

--
-- Given a Table Name, get the tablespace in which it lives.
--
FUNCTION GetTableSpaceName(tableNameParm VARCHAR2) RETURN VARCHAR2 AS
         tableSpaceName user_tables.table_name%TYPE := '';
BEGIN
  IF TableExists(tableNameParm) THEN
    SELECT u.tablespace_name INTO tableSpaceName
    FROM user_tables u
    WHERE UPPER(u.table_name) = tableNameParm;
  END IF;

  RETURN tableSpaceName;
EXCEPTION
WHEN NO_DATA_FOUND THEN
  RETURN NULL;
END GetTableSpaceName;

--
-- This routine logs an error to the dbms_output as well as the LOG_TABLE log.
--
PROCEDURE LogError (
	p_arrStatus		IN VARCHAR2,
	p_arrMessage	IN LONG,
	p_iErrorCode	IN NUMBER	DEFAULT NULL,
	p_iRecordNbr	IN NUMBER	DEFAULT NULL)
IS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	--dbms_output.put_line( p_arrStatus || ' ' || p_arrMessage || ' ' || p_iErrorCode || ' ' || p_iRecordNbr);

  INSERT INTO log_table (status, e_message, e_code, record_nbr)
		 VALUES	(p_arrStatus, p_arrMessage, p_iErrorCode, p_iRecordNbr);

	COMMIT;
END LogError;

--Log message procedure
PROCEDURE LogMesg (
    p_arrMessage    IN VARCHAR2)
  IS
    PRAGMA AUTONOMOUS_TRANSACTION;
    lv_record_no number;
  BEGIN
   select nvl(max(record_nbr),0) + 1 into lv_record_no from log_table;

  INSERT INTO log_table (record_nbr, e_message)
         VALUES    (lv_record_no, p_arrMessage);
    COMMIT;
  END;
  
FUNCTION get_shape_type (p_DimensionNbr aalwrk.dimension_number%TYPE,
                         p_SizeNbr      aalwrk.size_number%TYPE,
                         p_ColorNbr	aalwrk.color_number%TYPE)
RETURN NUMBER IS
     out_shape_type NUMBER;
BEGIN
	--
	-- Determine the shape type based on color, size and dimension
	-- 1 is dimension
	-- 2 is size
	-- 3 is color
	-- 4 is style
	--

    IF p_DimensionNbr IS NOT NULL THEN
        out_shape_type := const_dimension_shape;
    ELSE IF p_SizeNbr IS NOT NULL THEN
        out_shape_type := const_size_shape;
    ELSE IF p_ColorNbr IS NOT NULL THEN
        out_shape_type := const_color_shape;
    ELSE
        out_shape_type := const_style_shape;
    END IF;
    END IF;
    END IF;

   RETURN out_shape_type;
END get_shape_type;


FUNCTION func_wl_status_code (wlkey_in IN NUMBER)
RETURN NUMBER IS
	local_status	worklist.status_code%TYPE;
BEGIN
	SELECT	status_code
	  INTO	local_status
	  FROM	worklist
	 WHERE	wl_key	= wlkey_in;

	RETURN local_status;
EXCEPTION
	WHEN OTHERS THEN
		RETURN -1;
END func_wl_status_code;


-- This procedure will ensure that any results are removed before deleting any WorkList keys
-- in WL_DEL.
-- If a WorkList key is to be deleted and it is part of an existing allocation, the remaining
-- WorkList keys in the allocation will be marked with a trouble code indicating that part of
-- the allocation was deleted, and that the results were therefore lost.
PROCEDURE PrepareForWorkListDelete AS

CURSOR cur_AllocNbr IS
  SELECT distinct alloc_nbr
    FROM worklist
   WHERE wl_key in (select wl_key from wl_del)
     AND alloc_nbr > 0;

BEGIN

-- for every record in wl_del,
-- get the allocation number from the worklist
-- reset all lines with that allocation number to status 10,Status Code 'Available',
-- trouble code of 'DEL', allocation number of 0, user id null, dc_status stuff null; aa_job_nbr null
-- delete from results header for the allocation number
  FOR cur_rec in cur_AllocNbr LOOP

    UPDATE worklist
       SET alloc_nbr = 0, aa_job_nbr = null, user_id = null, status_code = 10,
           status_desc = 'Available', trouble_code = 'DEL', dc_rule_info = null,
           dc_status_code = null, dc_status_desc = null
     WHERE alloc_nbr = cur_rec.alloc_nbr;

    DELETE
      FROM results_header
     WHERE allocation_nbr = cur_rec.alloc_nbr;
  END LOOP;

  COMMIT; -- Must be committed so that mmstoolkit can delete from worklist


END PrepareForWorkListDelete;


/* Following procedure RebuildStageClass has been modified by Abhi Sharma (JDA Software):
   - Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes.
   - Modified the logic to include Regular Sales Columns - REG_SLS_01AG0 through
     REG_SLS_78AGO as per the CR changes.
*/
----New Rebuild procedure class level
-------------------------------------------------  Rebuild Stage_V_Class table
PROCEDURE RebuildStageClass AS
  -- Table space name
  stageClassTablespaceName user_tables.tablespace_name%TYPE;

  -- Saved DDL to recreate indexes for the STAGE_CLASS table.
  ddlForStage_Class DDL_tabType;

  -- Extent information for the STAGE_CLASS table.
  stageClassInitialExtent user_tables.initial_extent%TYPE;
  stageClassNextExtent    user_tables.next_extent%TYPE;
  stageClassMinExtent     user_tables.min_extents%TYPE;
  stageClassMaxExtent     user_tables.max_extents%TYPE;
  stageClassPctIncrease   user_tables.pct_increase%TYPE;

  strstageClassNextExtent VARCHAR2(30);
  strstageClassPctIncrease VARCHAR2(30);

BEGIN
  -- Get the tablespace of the STAGE_CLASS table.
  stageClassTablespaceName := GetTableSpaceName('STAGE_V_CLASS');

  -- Check for a good tablespace name
  IF stageClassTablespaceName IS NULL THEN
     LogError('', 'RebuildStageClass : Unable to determine the tablespace name for the stage_class table');
     RETURN;
  END IF;

  -- Get the extent information for the STAGE_DIMENSION and STAGE_CLASS tables.
  IF NOT Getextentinfo( 'STAGE_V_CLASS', stageClassInitialExtent, stageClassNextExtent, stageClassMinExtent, stageClassMaxExtent, stageClassPctIncrease ) THEN
    LogError('', 'RebuildStageClass :  Unable to determine the table extents for the stage_V_class table');
    RETURN;
  END IF;

  -- Omit NEXT if Next_Extent is not explicitly specified
  IF stageClassNextExtent IS NULL THEN
    strstageClassNextExtent := '';
  ELSE
    strstageClassNextExtent := ' NEXT ' || stageClassNextExtent;
  END IF;

  -- Omit PCTINCREASE if it is not explicitly specified
  IF stageClassPctIncrease IS NULL THEN
    strstageClassPctIncrease := '';
  ELSE
    strstageClassPctIncrease := ' PCTINCREASE ' || stageClassPctIncrease;
  END IF;

  -- Save the DDL in a local variable before we rename the table.
  ddlForStage_Class := AllocMMS.GetTableIndexAndKeyDDL('STAGE_V_CLASS');

  EXECUTE IMMEDIATE 'rename STAGE_V_CLASS to ' || OLD_STAGE_CLASS_TABLE_NAME;

  EXECUTE IMMEDIATE
    'CREATE TABLE ' ||
    'STAGE_V_CLASS ' ||
    'NOLOGGING ' ||
    'TABLESPACE    ' ||
    stageClassTablespaceName ||
    ' STORAGE (' ||
    ' INITIAL ' || stageClassInitialExtent ||
    strstageClassNextExtent ||
    ' MINEXTENTS ' || stageClassMinExtent ||
    ' MAXEXTENTS ' || stageClassMaxExtent ||
    strstageClassPctIncrease ||
    ' ) ' ||
    'AS ' ||
    'SELECT /*+FULL(stage_subclass) PARALLEL(stage_subclass) */ ' ||
    --'SELECT ' ||
    'location_id, ' ||
    'dept_nbr, ' ||
    'subdept_nbr, ' ||
    'class_nbr, ' ||
    'SUM(str_on_order)    AS str_on_order, ' ||
    'SUM(dnf_intransit)    AS dnf_intransit, ' ||
    'SUM(wtd_sales)    AS wtd_sales, ' ||
    'SUM(on_hand_curr)    AS on_hand_curr, ' ||
    'SUM(on_hand_01ago)    AS on_hand_01ago, ' ||
    'SUM(on_hand_02ago)    AS on_hand_02ago, ' ||
    'SUM(on_hand_03ago)    AS on_hand_03ago, ' ||
    'SUM(on_hand_04ago)    AS on_hand_04ago, ' ||
    'SUM(on_hand_05ago)    AS on_hand_05ago, ' ||
    'SUM(on_hand_06ago)    AS on_hand_06ago, ' ||
    'SUM(on_hand_07ago)    AS on_hand_07ago, ' ||
    'SUM(on_hand_08ago)    AS on_hand_08ago, ' ||
    'SUM(on_hand_09ago)    AS on_hand_09ago, ' ||
    'SUM(on_hand_10ago)    AS on_hand_10ago, ' ||
    'SUM(on_hand_11ago)    AS on_hand_11ago, ' ||
    'SUM(on_hand_12ago)    AS on_hand_12ago, ' ||
    'SUM(on_hand_13ago)    AS on_hand_13ago, ' ||
    'SUM(on_hand_14ago)    AS on_hand_14ago, ' ||
    'SUM(on_hand_15ago)    AS on_hand_15ago, ' ||
    'SUM(on_hand_16ago)    AS on_hand_16ago, ' ||
    'SUM(on_hand_17ago)    AS on_hand_17ago, ' ||
    'SUM(on_hand_18ago)    AS on_hand_18ago, ' ||
    'SUM(on_hand_19ago)    AS on_hand_19ago, ' ||
    'SUM(on_hand_20ago)    AS on_hand_20ago, ' ||
    'SUM(on_hand_21ago)    AS on_hand_21ago, ' ||
    'SUM(on_hand_22ago)    AS on_hand_22ago, ' ||
    'SUM(on_hand_23ago)    AS on_hand_23ago, ' ||
    'SUM(on_hand_24ago)    AS on_hand_24ago, ' ||
    'SUM(on_hand_25ago)    AS on_hand_25ago, ' ||
    'SUM(on_hand_26ago)    AS on_hand_26ago, ' ||
    'SUM(on_hand_27ago)    AS on_hand_27ago, ' ||
    'SUM(on_hand_28ago)    AS on_hand_28ago, ' ||
    'SUM(on_hand_29ago)    AS on_hand_29ago, ' ||
    'SUM(on_hand_30ago)    AS on_hand_30ago, ' ||
    'SUM(on_hand_31ago)    AS on_hand_31ago, ' ||
    'SUM(on_hand_32ago)    AS on_hand_32ago, ' ||
    'SUM(on_hand_33ago)    AS on_hand_33ago, ' ||
    'SUM(on_hand_34ago)    AS on_hand_34ago, ' ||
    'SUM(on_hand_35ago)    AS on_hand_35ago, ' ||
    'SUM(on_hand_36ago)    AS on_hand_36ago, ' ||
    'SUM(on_hand_37ago)    AS on_hand_37ago, ' ||
    'SUM(on_hand_38ago)    AS on_hand_38ago, ' ||
    'SUM(on_hand_39ago)    AS on_hand_39ago, ' ||
    'SUM(on_hand_40ago)    AS on_hand_40ago, ' ||
    'SUM(on_hand_41ago)    AS on_hand_41ago, ' ||
    'SUM(on_hand_42ago)    AS on_hand_42ago, ' ||
    'SUM(on_hand_43ago)    AS on_hand_43ago, ' ||
    'SUM(on_hand_44ago)    AS on_hand_44ago, ' ||
    'SUM(on_hand_45ago)    AS on_hand_45ago, ' ||
    'SUM(on_hand_46ago)    AS on_hand_46ago, ' ||
    'SUM(on_hand_47ago)    AS on_hand_47ago, ' ||
    'SUM(on_hand_48ago)    AS on_hand_48ago, ' ||
    'SUM(on_hand_49ago)    AS on_hand_49ago, ' ||
    'SUM(on_hand_50ago)    AS on_hand_50ago, ' ||
    'SUM(on_hand_51ago)    AS on_hand_51ago, ' ||
    'SUM(on_hand_52ago)    AS on_hand_52ago, ' ||
    'SUM(on_hand_53ago)    AS on_hand_53ago, ' ||
    'SUM(on_hand_54ago)    AS on_hand_54ago, ' ||
    'SUM(on_hand_55ago)    AS on_hand_55ago, ' ||
    'SUM(on_hand_56ago)    AS on_hand_56ago, ' ||
    'SUM(on_hand_57ago)    AS on_hand_57ago, ' ||
    'SUM(on_hand_58ago)    AS on_hand_58ago, ' ||
    'SUM(on_hand_59ago)    AS on_hand_59ago, ' ||
    'SUM(on_hand_60ago)    AS on_hand_60ago, ' ||
    'SUM(on_hand_61ago)    AS on_hand_61ago, ' ||
    'SUM(on_hand_62ago)    AS on_hand_62ago, ' ||
    'SUM(on_hand_63ago)    AS on_hand_63ago, ' ||
    'SUM(on_hand_64ago)    AS on_hand_64ago, ' ||
    'SUM(on_hand_65ago)    AS on_hand_65ago, ' ||
    'SUM(on_hand_66ago)    AS on_hand_66ago, ' ||
    'SUM(on_hand_67ago)    AS on_hand_67ago, ' ||
    'SUM(on_hand_68ago)    AS on_hand_68ago, ' ||
    'SUM(on_hand_69ago)    AS on_hand_69ago, ' ||
    'SUM(on_hand_70ago)    AS on_hand_70ago, ' ||
    'SUM(on_hand_71ago)    AS on_hand_71ago, ' ||
    'SUM(on_hand_72ago)    AS on_hand_72ago, ' ||
    'SUM(on_hand_73ago)    AS on_hand_73ago, ' ||
    'SUM(on_hand_74ago)    AS on_hand_74ago, ' ||
    'SUM(on_hand_75ago)    AS on_hand_75ago, ' ||
    'SUM(on_hand_76ago)    AS on_hand_76ago, ' ||
    'SUM(on_hand_77ago)    AS on_hand_77ago, ' ||
    'SUM(on_hand_78ago)    AS on_hand_78ago, ' ||
    'SUM(sls_01ago)    AS sls_01ago, ' ||
    'SUM(sls_02ago)    AS sls_02ago, ' ||
    'SUM(sls_03ago)    AS sls_03ago, ' ||
    'SUM(sls_04ago)    AS sls_04ago, ' ||
    'SUM(sls_05ago)    AS sls_05ago, ' ||
    'SUM(sls_06ago)    AS sls_06ago, ' ||
    'SUM(sls_07ago)    AS sls_07ago, ' ||
    'SUM(sls_08ago)    AS sls_08ago, ' ||
    'SUM(sls_09ago)    AS sls_09ago, ' ||
    'SUM(sls_10ago)    AS sls_10ago, ' ||
    'SUM(sls_11ago)    AS sls_11ago, ' ||
    'SUM(sls_12ago)    AS sls_12ago, ' ||
    'SUM(sls_13ago)    AS sls_13ago, ' ||
    'SUM(sls_14ago)    AS sls_14ago, ' ||
    'SUM(sls_15ago)    AS sls_15ago, ' ||
    'SUM(sls_16ago)    AS sls_16ago, ' ||
    'SUM(sls_17ago)    AS sls_17ago, ' ||
    'SUM(sls_18ago)    AS sls_18ago, ' ||
    'SUM(sls_19ago)    AS sls_19ago, ' ||
    'SUM(sls_20ago)    AS sls_20ago, ' ||
    'SUM(sls_21ago)    AS sls_21ago, ' ||
    'SUM(sls_22ago)    AS sls_22ago, ' ||
    'SUM(sls_23ago)    AS sls_23ago, ' ||
    'SUM(sls_24ago)    AS sls_24ago, ' ||
    'SUM(sls_25ago)    AS sls_25ago, ' ||
    'SUM(sls_26ago)    AS sls_26ago, ' ||
    'SUM(sls_27ago)    AS sls_27ago, ' ||
    'SUM(sls_28ago)    AS sls_28ago, ' ||
    'SUM(sls_29ago)    AS sls_29ago, ' ||
    'SUM(sls_30ago)    AS sls_30ago, ' ||
    'SUM(sls_31ago)    AS sls_31ago, ' ||
    'SUM(sls_32ago)    AS sls_32ago, ' ||
    'SUM(sls_33ago)    AS sls_33ago, ' ||
    'SUM(sls_34ago)    AS sls_34ago, ' ||
    'SUM(sls_35ago)    AS sls_35ago, ' ||
    'SUM(sls_36ago)    AS sls_36ago, ' ||
    'SUM(sls_37ago)    AS sls_37ago, ' ||
    'SUM(sls_38ago)    AS sls_38ago, ' ||
    'SUM(sls_39ago)    AS sls_39ago, ' ||
    'SUM(sls_40ago)    AS sls_40ago, ' ||
    'SUM(sls_41ago)    AS sls_41ago, ' ||
    'SUM(sls_42ago)    AS sls_42ago, ' ||
    'SUM(sls_43ago)    AS sls_43ago, ' ||
    'SUM(sls_44ago)    AS sls_44ago, ' ||
    'SUM(sls_45ago)    AS sls_45ago, ' ||
    'SUM(sls_46ago)    AS sls_46ago, ' ||
    'SUM(sls_47ago)    AS sls_47ago, ' ||
    'SUM(sls_48ago)    AS sls_48ago, ' ||
    'SUM(sls_49ago)    AS sls_49ago, ' ||
    'SUM(sls_50ago)    AS sls_50ago, ' ||
    'SUM(sls_51ago)    AS sls_51ago, ' ||
    'SUM(sls_52ago)    AS sls_52ago, ' ||
    'SUM(sls_53ago)    AS sls_53ago, ' ||
    'SUM(sls_54ago)    AS sls_54ago, ' ||
    'SUM(sls_55ago)    AS sls_55ago, ' ||
    'SUM(sls_56ago)    AS sls_56ago, ' ||
    'SUM(sls_57ago)    AS sls_57ago, ' ||
    'SUM(sls_58ago)    AS sls_58ago, ' ||
    'SUM(sls_59ago)    AS sls_59ago, ' ||
    'SUM(sls_60ago)    AS sls_60ago, ' ||
    'SUM(sls_61ago)    AS sls_61ago, ' ||
    'SUM(sls_62ago)    AS sls_62ago, ' ||
    'SUM(sls_63ago)    AS sls_63ago, ' ||
    'SUM(sls_64ago)    AS sls_64ago, ' ||
    'SUM(sls_65ago)    AS sls_65ago, ' ||
    'SUM(sls_66ago)    AS sls_66ago, ' ||
    'SUM(sls_67ago)    AS sls_67ago, ' ||
    'SUM(sls_68ago)    AS sls_68ago, ' ||
    'SUM(sls_69ago)    AS sls_69ago, ' ||
    'SUM(sls_70ago)    AS sls_70ago, ' ||
    'SUM(sls_71ago)    AS sls_71ago, ' ||
    'SUM(sls_72ago)    AS sls_72ago, ' ||
    'SUM(sls_73ago)    AS sls_73ago, ' ||
    'SUM(sls_74ago)    AS sls_74ago, ' ||
    'SUM(sls_75ago)    AS sls_75ago, ' ||
    'SUM(sls_76ago)    AS sls_76ago, ' ||
    'SUM(sls_77ago)    AS sls_77ago, ' ||
    'SUM(sls_78ago)    AS sls_78ago, ' ||
    'attr_1_code, '  ||
    'attr_2_code, '  ||
    'attr_3_code, '  ||
    'attr_4_code, '  ||
    'attr_5_code, '  ||
    'attr_6_code, '  ||
    'attr_7_code, '  ||
    'attr_8_code, '  ||
    'attr_9_code, '  ||
    'attr_10_code, '  ||
    'attr_11_code, '  ||
    'attr_12_code, '  ||
    'SUM (reg_sls_wtd) AS reg_sls_wtd,  ' ||
    'SUM (reg_sls_01ago) AS reg_sls_01ago, ' ||
    'SUM (reg_sls_02ago) AS reg_sls_02ago,  ' ||
    'SUM (reg_sls_03ago) AS reg_sls_03ago,  ' ||
    'SUM (reg_sls_04ago) AS reg_sls_04ago,  ' ||
    'SUM (reg_sls_05ago) AS reg_sls_05ago,  ' ||
    'SUM (reg_sls_06ago) AS reg_sls_06ago,  ' ||
    'SUM (reg_sls_07ago) AS reg_sls_07ago,  ' ||
    'SUM (reg_sls_08ago) AS reg_sls_08ago,  ' ||
    'SUM (reg_sls_09ago) AS reg_sls_09ago,  ' ||
    'SUM (reg_sls_10ago) AS reg_sls_10ago,  ' ||
    'SUM (reg_sls_11ago) AS reg_sls_11ago,  ' ||
    'SUM (reg_sls_12ago) AS reg_sls_12ago,  ' ||
    'SUM (reg_sls_13ago) AS reg_sls_13ago,  ' ||
    'SUM (reg_sls_14ago) AS reg_sls_14ago,  ' ||
    'SUM (reg_sls_15ago) AS reg_sls_15ago,  ' ||
    'SUM (reg_sls_16ago) AS reg_sls_16ago,  ' ||
    'SUM (reg_sls_17ago) AS reg_sls_17ago,  ' ||
    'SUM (reg_sls_18ago) AS reg_sls_18ago,  ' ||
    'SUM (reg_sls_19ago) AS reg_sls_19ago,  ' ||
    'SUM (reg_sls_20ago) AS reg_sls_20ago,  ' ||
    'SUM (reg_sls_21ago) AS reg_sls_21ago,  ' ||
    'SUM (reg_sls_22ago) AS reg_sls_22ago,  ' ||
    'SUM (reg_sls_23ago) AS reg_sls_23ago,  ' ||
    'SUM (reg_sls_24ago) AS reg_sls_24ago,  ' ||
    'SUM (reg_sls_25ago) AS reg_sls_25ago,  ' ||
    'SUM (reg_sls_26ago) AS reg_sls_26ago,  ' ||
    'SUM (reg_sls_27ago) AS reg_sls_27ago,  ' ||
    'SUM (reg_sls_28ago) AS reg_sls_28ago,  ' ||
    'SUM (reg_sls_29ago) AS reg_sls_29ago,  ' ||
    'SUM (reg_sls_30ago) AS reg_sls_30ago,  ' ||
    'SUM (reg_sls_31ago) AS reg_sls_31ago,  ' ||
    'SUM (reg_sls_32ago) AS reg_sls_32ago,  ' ||
    'SUM (reg_sls_33ago) AS reg_sls_33ago,  ' ||
    'SUM (reg_sls_34ago) AS reg_sls_34ago,  ' ||
    'SUM (reg_sls_35ago) AS reg_sls_35ago,  ' ||
    'SUM (reg_sls_36ago) AS reg_sls_36ago,  ' ||
    'SUM (reg_sls_37ago) AS reg_sls_37ago,  ' ||
    'SUM (reg_sls_38ago) AS reg_sls_38ago,  ' ||
    'SUM (reg_sls_39ago) AS reg_sls_39ago,  ' ||
    'SUM (reg_sls_40ago) AS reg_sls_40ago,  ' ||
    'SUM (reg_sls_41ago) AS reg_sls_41ago,  ' ||
    'SUM (reg_sls_42ago) AS reg_sls_42ago,  ' ||
    'SUM (reg_sls_43ago) AS reg_sls_43ago,  ' ||
    'SUM (reg_sls_44ago) AS reg_sls_44ago,  ' ||
    'SUM (reg_sls_45ago) AS reg_sls_45ago,  ' ||
    'SUM (reg_sls_46ago) AS reg_sls_46ago,  ' ||
    'SUM (reg_sls_47ago) AS reg_sls_47ago,  ' ||
    'SUM (reg_sls_48ago) AS reg_sls_48ago,  ' ||
    'SUM (reg_sls_49ago) AS reg_sls_49ago,  ' ||
    'SUM (reg_sls_50ago) AS reg_sls_50ago,  ' ||
    'SUM (reg_sls_51ago) AS reg_sls_51ago,  ' ||
    'SUM (reg_sls_52ago) AS reg_sls_52ago,  ' ||
    'SUM (reg_sls_53ago) AS reg_sls_53ago,  ' ||
    'SUM (reg_sls_54ago) AS reg_sls_54ago,  ' ||
    'SUM (reg_sls_55ago) AS reg_sls_55ago,  ' ||
    'SUM (reg_sls_56ago) AS reg_sls_56ago,  ' ||
    'SUM (reg_sls_57ago) AS reg_sls_57ago,  ' ||
    'SUM (reg_sls_58ago) AS reg_sls_58ago,  ' ||
    'SUM (reg_sls_59ago) AS reg_sls_59ago,  ' ||
    'SUM (reg_sls_60ago) AS reg_sls_60ago,  ' ||
    'SUM (reg_sls_61ago) AS reg_sls_61ago,  ' ||
    'SUM (reg_sls_62ago) AS reg_sls_62ago,  ' ||
    'SUM (reg_sls_63ago) AS reg_sls_63ago,  ' ||
    'SUM (reg_sls_64ago) AS reg_sls_64ago,  ' ||
    'SUM (reg_sls_65ago) AS reg_sls_65ago,  ' ||
    'SUM (reg_sls_66ago) AS reg_sls_66ago,  ' ||
    'SUM (reg_sls_67ago) AS reg_sls_67ago,  ' ||
    'SUM (reg_sls_68ago) AS reg_sls_68ago,  ' ||
    'SUM (reg_sls_69ago) AS reg_sls_69ago,  ' ||
    'SUM (reg_sls_70ago) AS reg_sls_70ago,  ' ||
    'SUM (reg_sls_71ago) AS reg_sls_71ago,  ' ||
    'SUM (reg_sls_72ago) AS reg_sls_72ago,  ' ||
    'SUM (reg_sls_73ago) AS reg_sls_73ago,  ' ||
    'SUM (reg_sls_74ago) AS reg_sls_74ago,  ' ||
    'SUM (reg_sls_75ago) AS reg_sls_75ago,  ' ||
    'SUM (reg_sls_76ago) AS reg_sls_76ago,  ' ||
    'SUM (reg_sls_77ago) AS reg_sls_77ago,  ' ||
    'SUM (reg_sls_78ago) AS reg_sls_78ago   ' ||
    '    FROM stage_subclass ' ||
    '    GROUP BY dept_nbr, subdept_nbr, class_nbr, location_id, attr_1_code,attr_2_code,attr_3_code,attr_4_code,attr_5_code, attr_6_code, attr_7_code, attr_8_code, attr_9_code, attr_10_code, attr_11_code, attr_12_code';


  EXECUTE IMMEDIATE 'drop TABLE ' || OLD_STAGE_CLASS_TABLE_NAME;

  -- Create the indexes for the stage_class table.
  BEGIN
    AllocMMS.ExecutedIndexAndKeyDDL(ddlForStage_Class);

  EXCEPTION
     WHEN OTHERS THEN
          LogError('', 'RebuildStageClass : Unable to recreate index(es) for the STAGE_V_CLASS table.  Any indexes will have to be manually created.');
     RAISE;
  END;

EXCEPTION

  WHEN OTHERS THEN


  IF TableExists(OLD_STAGE_CLASS_TABLE_NAME) THEN
    IF TableExists('STAGE_V_CLASS') THEN
       EXECUTE IMMEDIATE 'drop table STAGE_V_CLASS';
    END IF;
    EXECUTE IMMEDIATE 'rename ' || OLD_STAGE_CLASS_TABLE_NAME || ' to STAGE_V_CLASS';
  END IF;

  RAISE;  -- Reraise exception

END RebuildStageClass;

/* Following procedure RebuildStageSubclass has been modified by Abhi Sharma (JDA Software):
   - Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes.
   - Modified the logic to include Regular Sales Columns - REG_SLS_01AG0 through
     REG_SLS_78AGO as per the CR changes.
*/
--
-- This procedure synchronizes the STAGE_SUBCLASS table with the
-- entries in the STAGE_DIMENSION table.  It is used instead of UpdtStageSubclassFromStageDim
-- for cases where multiple STAGE_DIMENSION records are being affected.
--
PROCEDURE RebuildStageSubclass AS
  -- Table space name
  stageSubclassTablespaceName user_tables.tablespace_name%TYPE;

  -- Saved DDL to recreate indexes for the STAGE_SUBCLASS table.
  ddlForStage_Subclass DDL_tabType;

  -- Extent information for the STAGE_SUBCLASS table.
--  stageSubClassInitialExtent PLS_INTEGER;
--  stageSubClassNextExtent PLS_INTEGER;
--  stageSubClassMinExtent PLS_INTEGER;
--  stageSubClassMaxExtent PLS_INTEGER;
--  stageSubClassPctIncrease PLS_INTEGER;

  stageSubClassInitialExtent user_tables.initial_extent%TYPE;
  stageSubClassNextExtent    user_tables.next_extent%TYPE;
  stageSubClassMinExtent     user_tables.min_extents%TYPE;
  stageSubClassMaxExtent     user_tables.max_extents%TYPE;
  stageSubClassPctIncrease   user_tables.pct_increase%TYPE;

  strstageSubclassNextExtent VARCHAR2(30);
  strstageSubclassPctIncrease VARCHAR2(30);

BEGIN
  -- Get the tablespace of the STAGE_SUBCLASS table.
  stageSubclassTablespaceName := GetTableSpaceName('STAGE_SUBCLASS');

  -- Check for a good tablespace name
  IF stageSubclassTablespaceName IS NULL THEN
     LogError('', 'RebuildStageSubclass : Unable to determine the tablespace name for the stage_subclass table');
     RETURN;
  END IF;

  -- Get the extent information for the STAGE_DIMENSION and STAGE_SUBCLASS tables.
  IF NOT Getextentinfo( 'STAGE_SUBCLASS', stageSubclassInitialExtent, stageSubclassNextExtent, stageSubclassMinExtent, stageSubclassMaxExtent, stageSubclassPctIncrease ) THEN
    LogError('', 'RebuildStageSubclass :  Unable to determine the table extents for the stage_subclass table');
    RETURN;
  END IF;

  -- Omit NEXT if Next_Extent is not explicitly specified
  IF stageSubclassNextExtent IS NULL THEN
    strstageSubclassNextExtent := '';
  ELSE
    strstageSubclassNextExtent := ' NEXT ' || stageSubclassNextExtent;
  END IF;

  -- Omit PCTINCREASE if it is not explicitly specified
  IF stageSubclassPctIncrease IS NULL THEN
    strstageSubclassPctIncrease := '';
  ELSE
    strstageSubclassPctIncrease := ' PCTINCREASE ' || stageSubclassPctIncrease;
  END IF;

  -- Save the DDL in a local variable before we rename the table.
  ddlForStage_Subclass := AllocMMS.GetTableIndexAndKeyDDL('STAGE_SUBCLASS');

  EXECUTE IMMEDIATE 'rename STAGE_SUBCLASS to ' || OLD_STAGE_SUBCLASS_TABLE_NAME;

  EXECUTE IMMEDIATE
    'CREATE TABLE ' ||
    'STAGE_SUBCLASS ' ||
    'NOLOGGING ' ||
    'TABLESPACE	' ||
    stageSubclassTablespaceName ||
    ' STORAGE (' ||
    ' INITIAL ' || stageSubclassInitialExtent ||
    strstageSubclassNextExtent ||
    ' MINEXTENTS ' || stageSubclassMinExtent ||
    ' MAXEXTENTS ' || stageSubclassMaxExtent ||
    strstageSubclassPctIncrease ||
    ' ) ' ||
    'AS ' ||
    'SELECT /*+FULL(stage_dimension) PARALLEL(stage_dimension) */ ' ||
    'location_id, ' ||
    'dept_nbr, ' ||
    'subdept_nbr, ' ||
    'class_nbr, ' ||
    'item_group_nbr,' ||
    'subclass_nbr, ' ||
    'SUM(str_on_order)	AS str_on_order, ' ||
    'SUM(dnf_intransit)	AS dnf_intransit, ' ||
    'SUM(wtd_sales)	AS wtd_sales, ' ||
    'SUM(on_hand_curr)	AS on_hand_curr, ' ||
    'SUM(on_hand_01ago)	AS on_hand_01ago, ' ||
    'SUM(on_hand_02ago)	AS on_hand_02ago, ' ||
    'SUM(on_hand_03ago)	AS on_hand_03ago, ' ||
    'SUM(on_hand_04ago)	AS on_hand_04ago, ' ||
    'SUM(on_hand_05ago)	AS on_hand_05ago, ' ||
    'SUM(on_hand_06ago)	AS on_hand_06ago, ' ||
    'SUM(on_hand_07ago)	AS on_hand_07ago, ' ||
    'SUM(on_hand_08ago)	AS on_hand_08ago, ' ||
    'SUM(on_hand_09ago)	AS on_hand_09ago, ' ||
    'SUM(on_hand_10ago)	AS on_hand_10ago, ' ||
    'SUM(on_hand_11ago)	AS on_hand_11ago, ' ||
    'SUM(on_hand_12ago)	AS on_hand_12ago, ' ||
    'SUM(on_hand_13ago)	AS on_hand_13ago, ' ||
    'SUM(on_hand_14ago)	AS on_hand_14ago, ' ||
    'SUM(on_hand_15ago)	AS on_hand_15ago, ' ||
    'SUM(on_hand_16ago)	AS on_hand_16ago, ' ||
    'SUM(on_hand_17ago)	AS on_hand_17ago, ' ||
    'SUM(on_hand_18ago)	AS on_hand_18ago, ' ||
    'SUM(on_hand_19ago)	AS on_hand_19ago, ' ||
    'SUM(on_hand_20ago)	AS on_hand_20ago, ' ||
    'SUM(on_hand_21ago)	AS on_hand_21ago, ' ||
    'SUM(on_hand_22ago)	AS on_hand_22ago, ' ||
    'SUM(on_hand_23ago)	AS on_hand_23ago, ' ||
    'SUM(on_hand_24ago)	AS on_hand_24ago, ' ||
    'SUM(on_hand_25ago)	AS on_hand_25ago, ' ||
    'SUM(on_hand_26ago)	AS on_hand_26ago, ' ||
    'SUM(on_hand_27ago)	AS on_hand_27ago, ' ||
    'SUM(on_hand_28ago)	AS on_hand_28ago, ' ||
    'SUM(on_hand_29ago)	AS on_hand_29ago, ' ||
    'SUM(on_hand_30ago)	AS on_hand_30ago, ' ||
    'SUM(on_hand_31ago)	AS on_hand_31ago, ' ||
    'SUM(on_hand_32ago)	AS on_hand_32ago, ' ||
    'SUM(on_hand_33ago)	AS on_hand_33ago, ' ||
    'SUM(on_hand_34ago)	AS on_hand_34ago, ' ||
    'SUM(on_hand_35ago)	AS on_hand_35ago, ' ||
    'SUM(on_hand_36ago)	AS on_hand_36ago, ' ||
    'SUM(on_hand_37ago)	AS on_hand_37ago, ' ||
    'SUM(on_hand_38ago)	AS on_hand_38ago, ' ||
    'SUM(on_hand_39ago)	AS on_hand_39ago, ' ||
    'SUM(on_hand_40ago)	AS on_hand_40ago, ' ||
    'SUM(on_hand_41ago)	AS on_hand_41ago, ' ||
    'SUM(on_hand_42ago)	AS on_hand_42ago, ' ||
    'SUM(on_hand_43ago)	AS on_hand_43ago, ' ||
    'SUM(on_hand_44ago)	AS on_hand_44ago, ' ||
    'SUM(on_hand_45ago)	AS on_hand_45ago, ' ||
    'SUM(on_hand_46ago)	AS on_hand_46ago, ' ||
    'SUM(on_hand_47ago)	AS on_hand_47ago, ' ||
    'SUM(on_hand_48ago)	AS on_hand_48ago, ' ||
    'SUM(on_hand_49ago)	AS on_hand_49ago, ' ||
    'SUM(on_hand_50ago)	AS on_hand_50ago, ' ||
    'SUM(on_hand_51ago)	AS on_hand_51ago, ' ||
    'SUM(on_hand_52ago)	AS on_hand_52ago, ' ||
    'SUM(on_hand_53ago)	AS on_hand_53ago, ' ||
    'SUM(on_hand_54ago)	AS on_hand_54ago, ' ||
    'SUM(on_hand_55ago)	AS on_hand_55ago, ' ||
    'SUM(on_hand_56ago)	AS on_hand_56ago, ' ||
    'SUM(on_hand_57ago)	AS on_hand_57ago, ' ||
    'SUM(on_hand_58ago)	AS on_hand_58ago, ' ||
    'SUM(on_hand_59ago)	AS on_hand_59ago, ' ||
    'SUM(on_hand_60ago)	AS on_hand_60ago, ' ||
    'SUM(on_hand_61ago)	AS on_hand_61ago, ' ||
    'SUM(on_hand_62ago) AS on_hand_62ago, ' ||
    'SUM(on_hand_63ago) AS on_hand_63ago, ' ||
    'SUM(on_hand_64ago) AS on_hand_64ago, ' ||
    'SUM(on_hand_65ago) AS on_hand_65ago, ' ||
    'SUM(on_hand_66ago) AS on_hand_66ago, ' ||
    'SUM(on_hand_67ago) AS on_hand_67ago, ' ||
    'SUM(on_hand_68ago) AS on_hand_68ago, ' ||
    'SUM(on_hand_69ago) AS on_hand_69ago, ' ||
    'SUM(on_hand_70ago) AS on_hand_70ago, ' ||
    'SUM(on_hand_71ago) AS on_hand_71ago, ' ||
    'SUM(on_hand_72ago) AS on_hand_72ago, ' ||
    'SUM(on_hand_73ago) AS on_hand_73ago, ' ||
    'SUM(on_hand_74ago) AS on_hand_74ago, ' ||
    'SUM(on_hand_75ago) AS on_hand_75ago, ' ||
    'SUM(on_hand_76ago) AS on_hand_76ago, ' ||
    'SUM(on_hand_77ago) AS on_hand_77ago, ' ||
    'SUM(on_hand_78ago) AS on_hand_78ago, ' ||
    'SUM(sls_01ago)	AS sls_01ago, ' ||
    'SUM(sls_02ago)	AS sls_02ago, ' ||
    'SUM(sls_03ago)	AS sls_03ago, ' ||
    'SUM(sls_04ago)	AS sls_04ago, ' ||
    'SUM(sls_05ago)	AS sls_05ago, ' ||
    'SUM(sls_06ago)	AS sls_06ago, ' ||
    'SUM(sls_07ago)	AS sls_07ago, ' ||
    'SUM(sls_08ago)	AS sls_08ago, ' ||
    'SUM(sls_09ago)	AS sls_09ago, ' ||
    'SUM(sls_10ago)	AS sls_10ago, ' ||
    'SUM(sls_11ago)	AS sls_11ago, ' ||
    'SUM(sls_12ago)	AS sls_12ago, ' ||
    'SUM(sls_13ago)	AS sls_13ago, ' ||
    'SUM(sls_14ago)	AS sls_14ago, ' ||
    'SUM(sls_15ago)	AS sls_15ago, ' ||
    'SUM(sls_16ago)	AS sls_16ago, ' ||
    'SUM(sls_17ago)	AS sls_17ago, ' ||
    'SUM(sls_18ago)	AS sls_18ago, ' ||
    'SUM(sls_19ago)	AS sls_19ago, ' ||
    'SUM(sls_20ago)	AS sls_20ago, ' ||
    'SUM(sls_21ago)	AS sls_21ago, ' ||
    'SUM(sls_22ago)	AS sls_22ago, ' ||
    'SUM(sls_23ago)	AS sls_23ago, ' ||
    'SUM(sls_24ago)	AS sls_24ago, ' ||
    'SUM(sls_25ago)	AS sls_25ago, ' ||
    'SUM(sls_26ago)	AS sls_26ago, ' ||
    'SUM(sls_27ago)	AS sls_27ago, ' ||
    'SUM(sls_28ago)	AS sls_28ago, ' ||
    'SUM(sls_29ago)	AS sls_29ago, ' ||
    'SUM(sls_30ago)	AS sls_30ago, ' ||
    'SUM(sls_31ago)	AS sls_31ago, ' ||
    'SUM(sls_32ago)	AS sls_32ago, ' ||
    'SUM(sls_33ago)	AS sls_33ago, ' ||
    'SUM(sls_34ago)	AS sls_34ago, ' ||
    'SUM(sls_35ago)	AS sls_35ago, ' ||
    'SUM(sls_36ago)	AS sls_36ago, ' ||
    'SUM(sls_37ago)	AS sls_37ago, ' ||
    'SUM(sls_38ago)	AS sls_38ago, ' ||
    'SUM(sls_39ago)	AS sls_39ago, ' ||
    'SUM(sls_40ago)	AS sls_40ago, ' ||
    'SUM(sls_41ago)	AS sls_41ago, ' ||
    'SUM(sls_42ago)	AS sls_42ago, ' ||
    'SUM(sls_43ago)	AS sls_43ago, ' ||
    'SUM(sls_44ago)	AS sls_44ago, ' ||
    'SUM(sls_45ago)	AS sls_45ago, ' ||
    'SUM(sls_46ago)	AS sls_46ago, ' ||
    'SUM(sls_47ago)	AS sls_47ago, ' ||
    'SUM(sls_48ago)	AS sls_48ago, ' ||
    'SUM(sls_49ago)	AS sls_49ago, ' ||
    'SUM(sls_50ago)	AS sls_50ago, ' ||
    'SUM(sls_51ago)	AS sls_51ago, ' ||
    'SUM(sls_52ago)	AS sls_52ago, ' ||
    'SUM(sls_53ago)	AS sls_53ago, ' ||
    'SUM(sls_54ago)	AS sls_54ago, ' ||
    'SUM(sls_55ago)	AS sls_55ago, ' ||
    'SUM(sls_56ago)	AS sls_56ago, ' ||
    'SUM(sls_57ago)	AS sls_57ago, ' ||
    'SUM(sls_58ago)	AS sls_58ago, ' ||
    'SUM(sls_59ago)	AS sls_59ago, ' ||
    'SUM(sls_60ago)	AS sls_60ago, ' ||
    'SUM(sls_61ago)	AS sls_61ago, ' ||
    'SUM(sls_62ago)	AS sls_62ago, ' ||
    'SUM(sls_63ago)	AS sls_63ago, ' ||
    'SUM(sls_64ago)	AS sls_64ago, ' ||
    'SUM(sls_65ago)	AS sls_65ago, ' ||
    'SUM(sls_66ago)	AS sls_66ago, ' ||
    'SUM(sls_67ago)	AS sls_67ago, ' ||
    'SUM(sls_68ago)	AS sls_68ago, ' ||
    'SUM(sls_69ago)	AS sls_69ago, ' ||
    'SUM(sls_70ago)	AS sls_70ago, ' ||
    'SUM(sls_71ago)	AS sls_71ago, ' ||
    'SUM(sls_72ago)	AS sls_72ago, ' ||
    'SUM(sls_73ago)	AS sls_73ago, ' ||
    'SUM(sls_74ago)	AS sls_74ago, ' ||
    'SUM(sls_75ago)	AS sls_75ago, ' ||
    'SUM(sls_76ago)	AS sls_76ago, ' ||
    'SUM(sls_77ago)	AS sls_77ago, ' ||
    'SUM(sls_78ago)	AS sls_78ago, ' ||
    'attr_1_code, '  ||
    'attr_2_code, '  ||
    'attr_3_code, '  ||
    'attr_4_code, '  ||
    'attr_5_code, '  ||
    'attr_6_code, '  ||
    'attr_7_code, '  ||
    'attr_8_code, '  ||
    'attr_9_code, '  ||
    'attr_10_code, '  ||
    'attr_11_code, '  ||
    'attr_12_code, '  ||
    'SUM (reg_sls_wtd) AS reg_sls_wtd,  ' ||
    'SUM (reg_sls_01ago) AS reg_sls_01ago, ' ||
    'SUM (reg_sls_02ago) AS reg_sls_02ago,  ' ||
    'SUM (reg_sls_03ago) AS reg_sls_03ago,  ' ||
    'SUM (reg_sls_04ago) AS reg_sls_04ago,  ' ||
    'SUM (reg_sls_05ago) AS reg_sls_05ago,  ' ||
    'SUM (reg_sls_06ago) AS reg_sls_06ago,  ' ||
    'SUM (reg_sls_07ago) AS reg_sls_07ago,  ' ||
    'SUM (reg_sls_08ago) AS reg_sls_08ago,  ' ||
    'SUM (reg_sls_09ago) AS reg_sls_09ago,  ' ||
    'SUM (reg_sls_10ago) AS reg_sls_10ago,  ' ||
    'SUM (reg_sls_11ago) AS reg_sls_11ago,  ' ||
    'SUM (reg_sls_12ago) AS reg_sls_12ago,  ' ||
    'SUM (reg_sls_13ago) AS reg_sls_13ago,  ' ||
    'SUM (reg_sls_14ago) AS reg_sls_14ago,  ' ||
    'SUM (reg_sls_15ago) AS reg_sls_15ago,  ' ||
    'SUM (reg_sls_16ago) AS reg_sls_16ago,  ' ||
    'SUM (reg_sls_17ago) AS reg_sls_17ago,  ' ||
    'SUM (reg_sls_18ago) AS reg_sls_18ago,  ' ||
    'SUM (reg_sls_19ago) AS reg_sls_19ago,  ' ||
    'SUM (reg_sls_20ago) AS reg_sls_20ago,  ' ||
    'SUM (reg_sls_21ago) AS reg_sls_21ago,  ' ||
    'SUM (reg_sls_22ago) AS reg_sls_22ago,  ' ||
    'SUM (reg_sls_23ago) AS reg_sls_23ago,  ' ||
    'SUM (reg_sls_24ago) AS reg_sls_24ago,  ' ||
    'SUM (reg_sls_25ago) AS reg_sls_25ago,  ' ||
    'SUM (reg_sls_26ago) AS reg_sls_26ago,  ' ||
    'SUM (reg_sls_27ago) AS reg_sls_27ago,  ' ||
    'SUM (reg_sls_28ago) AS reg_sls_28ago,  ' ||
    'SUM (reg_sls_29ago) AS reg_sls_29ago,  ' ||
    'SUM (reg_sls_30ago) AS reg_sls_30ago,  ' ||
    'SUM (reg_sls_31ago) AS reg_sls_31ago,  ' ||
    'SUM (reg_sls_32ago) AS reg_sls_32ago,  ' ||
    'SUM (reg_sls_33ago) AS reg_sls_33ago,  ' ||
    'SUM (reg_sls_34ago) AS reg_sls_34ago,  ' ||
    'SUM (reg_sls_35ago) AS reg_sls_35ago,  ' ||
    'SUM (reg_sls_36ago) AS reg_sls_36ago,  ' ||
    'SUM (reg_sls_37ago) AS reg_sls_37ago,  ' ||
    'SUM (reg_sls_38ago) AS reg_sls_38ago,  ' ||
    'SUM (reg_sls_39ago) AS reg_sls_39ago,  ' ||
    'SUM (reg_sls_40ago) AS reg_sls_40ago,  ' ||
    'SUM (reg_sls_41ago) AS reg_sls_41ago,  ' ||
    'SUM (reg_sls_42ago) AS reg_sls_42ago,  ' ||
    'SUM (reg_sls_43ago) AS reg_sls_43ago,  ' ||
    'SUM (reg_sls_44ago) AS reg_sls_44ago,  ' ||
    'SUM (reg_sls_45ago) AS reg_sls_45ago,  ' ||
    'SUM (reg_sls_46ago) AS reg_sls_46ago,  ' ||
    'SUM (reg_sls_47ago) AS reg_sls_47ago,  ' ||
    'SUM (reg_sls_48ago) AS reg_sls_48ago,  ' ||
    'SUM (reg_sls_49ago) AS reg_sls_49ago,  ' ||
    'SUM (reg_sls_50ago) AS reg_sls_50ago,  ' ||
    'SUM (reg_sls_51ago) AS reg_sls_51ago,  ' ||
    'SUM (reg_sls_52ago) AS reg_sls_52ago,  ' ||
    'SUM (reg_sls_53ago) AS reg_sls_53ago,  ' ||
    'SUM (reg_sls_54ago) AS reg_sls_54ago,  ' ||
    'SUM (reg_sls_55ago) AS reg_sls_55ago,  ' ||
    'SUM (reg_sls_56ago) AS reg_sls_56ago,  ' ||
    'SUM (reg_sls_57ago) AS reg_sls_57ago,  ' ||
    'SUM (reg_sls_58ago) AS reg_sls_58ago,  ' ||
    'SUM (reg_sls_59ago) AS reg_sls_59ago,  ' ||
    'SUM (reg_sls_60ago) AS reg_sls_60ago,  ' ||
    'SUM (reg_sls_61ago) AS reg_sls_61ago,  ' ||
    'SUM (reg_sls_62ago) AS reg_sls_62ago,  ' ||
    'SUM (reg_sls_63ago) AS reg_sls_63ago,  ' ||
    'SUM (reg_sls_64ago) AS reg_sls_64ago,  ' ||
    'SUM (reg_sls_65ago) AS reg_sls_65ago,  ' ||
    'SUM (reg_sls_66ago) AS reg_sls_66ago,  ' ||
    'SUM (reg_sls_67ago) AS reg_sls_67ago,  ' ||
    'SUM (reg_sls_68ago) AS reg_sls_68ago,  ' ||
    'SUM (reg_sls_69ago) AS reg_sls_69ago,  ' ||
    'SUM (reg_sls_70ago) AS reg_sls_70ago,  ' ||
    'SUM (reg_sls_71ago) AS reg_sls_71ago,  ' ||
    'SUM (reg_sls_72ago) AS reg_sls_72ago,  ' ||
    'SUM (reg_sls_73ago) AS reg_sls_73ago,  ' ||
    'SUM (reg_sls_74ago) AS reg_sls_74ago,  ' ||
    'SUM (reg_sls_75ago) AS reg_sls_75ago,  ' ||
    'SUM (reg_sls_76ago) AS reg_sls_76ago,  ' ||
    'SUM (reg_sls_77ago) AS reg_sls_77ago,  ' ||
    'SUM (reg_sls_78ago) AS reg_sls_78ago   ' ||
    '    FROM stage_dimension ' ||
    '    GROUP BY dept_nbr, subdept_nbr, class_nbr, item_group_nbr,subclass_nbr, location_id, attr_1_code,attr_2_code,attr_3_code,attr_4_code,attr_5_code,attr_6_code,attr_7_code,attr_8_code, attr_9_code, attr_10_code, attr_11_code, attr_12_code';


  EXECUTE IMMEDIATE 'drop TABLE ' || OLD_STAGE_SUBCLASS_TABLE_NAME;

  -- Create the indexes for the stage_subclass table.
  BEGIN
    AllocMMS.ExecutedIndexAndKeyDDL(ddlForStage_Subclass);

  EXCEPTION
     WHEN OTHERS THEN
          LogError('', 'RebuildStageSubclass : Unable to recreate index(es) for the STAGE_SUBCLASS table.  Any indexes will have to be manually created.');
     RAISE;
  END;

EXCEPTION

  WHEN OTHERS THEN


  IF TableExists(OLD_STAGE_SUBCLASS_TABLE_NAME) THEN
    IF TableExists('STAGE_SUBCLASS') THEN
       EXECUTE IMMEDIATE 'drop table STAGE_SUBCLASS';
    END IF;
    EXECUTE IMMEDIATE 'rename ' || OLD_STAGE_SUBCLASS_TABLE_NAME || ' to STAGE_SUBCLASS';
  END IF;

  RAISE;  -- Reraise exception

END RebuildStageSubclass;


PROCEDURE proc_wlkey  (
	po_src		IN worklist.po_nbr%TYPE,
	bo_src		IN worklist.bo_nbr%TYPE,
	Master_sku_src	IN worklist.style_master_sku%TYPE,
	color_src		IN aalwrk.color_number%TYPE,
	size_src		IN aalwrk.size_number%TYPE,
	dimension_src   	IN aalwrk.dimension_number%TYPE,
	vendor_packid	IN worklist.vendor_pack_id%TYPE,
	qty_per_pack    	IN worklist.qty_per_pack%TYPE DEFAULT NULL,
	pack_sku        	IN worklist.pack_id%TYPE,
      receiving_src   	IN worklist.receiving_id%TYPE,
	out_pack_id     	OUT VARCHAR2,
	out_shape_type	OUT NUMBER,
	out_new_wlkey   	OUT worklist.wl_key%TYPE
	) AS
BEGIN
	-- Initialize Shape Type with NULL
	out_shape_type := NULL;

	-- If vendor_pack_id is null then build pack_id if qty > 0
	 IF (vendor_packid IS NULL) AND (qty_per_pack > 1) THEN
	   --
	   -- If vendor pack id is null and if qty_per_pack is greater than
	   -- or equal to 1, then append qty_per_pack to the pack id.
	   --
     out_pack_id := pack_sku || '_' || qty_per_pack;
   ELSE
      out_pack_id := pack_sku;
   END IF;

	--
	-- Determine the shape type first based on master_sku, color and dimension
	-- 1 is dimension
	-- 2 is size
	-- 3 is color
	-- 4 is style
	--
	out_shape_type := get_shape_type(dimension_src, size_src, color_src);

  IF (vendor_packid is NULL) THEN -- vendor_packid is null; this is NOT a vendor pack.
    BEGIN
      IF (color_src is NULL) THEN -- vendor_packid is null; this is NOT a vendor pack,but it is a style-only line. Key columns are: PO_nbr/BO_nbr/Style_Master_SKU/Color (null)/shape_type/vendor_PackId/receiving_id
      -- This is separate so the query doesn't have to use NVL to get around null color, which was causing Oracle to ignore the index
        BEGIN
        	SELECT	wl_key /*+ index(WORKLIST_MAIN_KEY1_IDX) */
        	  INTO	out_new_wlkey
        	  FROM	worklist
        	 WHERE	po_nbr	= NVL(po_src, 0)
        	   AND	bo_nbr	= NVL(bo_src, 0)
        	   AND	style_master_sku = NVL(master_sku_src, 0)
        	   AND  vendor_pack_id is null
             AND  color_nbr is null
        	   AND	shape_type	= out_shape_type
        	   AND	receiving_id = NVL(receiving_src, 0)
        	   AND	status_code <> const_released;
        EXCEPTION
        	WHEN NO_DATA_FOUND THEN
        	out_new_wlkey := 0;
        END;

      ELSE -- vendor_packid is null; this is NOT a vendor pack, and it has a color level (maybe even size and dimension). Key columns are: PO_nbr/BO_nbr/Style_Master_SKU/Color/shape_type/vendor_PackId/receiving_id
        BEGIN
        	SELECT	wl_key /*+ index(WORKLIST_MAIN_KEY1_IDX) */
        	  INTO	out_new_wlkey
        	  FROM	worklist
        	 WHERE	po_nbr	= NVL(po_src, 0)
        	   AND	bo_nbr	= NVL(bo_src, 0)
        	   AND	style_master_sku = NVL(master_sku_src, 0)
        	   AND  vendor_pack_id is null
             AND  color_nbr = color_src
        	   AND	shape_type	= out_shape_type
        	   AND	receiving_id = NVL(receiving_src, 0)
        	   AND	status_code <> const_released;
        EXCEPTION
        	WHEN NO_DATA_FOUND THEN
        	out_new_wlkey := 0;
        END;
      END IF;
    END;

  ELSE -- vendor_packid not null; this IS a vendor pack. Key columns are: PO_nbr/BO_nbr/Style_Master_SKU/shape_type/vendor_PackId/receiving_id
    BEGIN
    	SELECT	wl_key /*+ index(WORKLIST_MAIN_KEY2_IDX) */
    	  INTO	out_new_wlkey
    	  FROM	worklist
    	 WHERE	po_nbr	= NVL(po_src, 0)
    	   AND	bo_nbr	= NVL(bo_src, 0)
    	   AND	style_master_sku = NVL(master_sku_src, 0)
    	   AND	shape_type	= out_shape_type
    	   AND  vendor_pack_id = vendor_packid
    	   AND	receiving_id = NVL(receiving_src, 0)
    	   AND	status_code <> const_released;
    EXCEPTION
    	WHEN NO_DATA_FOUND THEN
    	out_new_wlkey := 0;
    END;

  END IF;

END proc_wlkey;


FUNCTION func_next_wlkey
RETURN NUMBER IS
	local_wlkey		worklist.wl_key%TYPE;
BEGIN
	SELECT	MAX(wl_key) + 1
	  INTO	local_wlkey
	  FROM	worklist;

	-- The next three lines would only get
	-- executed if there is a worklist wl_key
	-- that is 0 - an unlikely case.
	IF (local_wlkey IS NULL) OR (local_wlkey < 1) THEN
		RETURN 1;
	END IF;

	RETURN local_wlkey;
EXCEPTION
	WHEN OTHERS THEN
		RETURN 0;
END func_next_wlkey;

FUNCTION func_is_valid_date (date_in IN NUMBER)
RETURN DATE IS
	temp_date	DATE;
BEGIN
	temp_date	:= TO_DATE (TO_CHAR(date_in), 'YYYYMMDD');

	RETURN temp_date;
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END func_is_valid_date;


-- Returns true if the worklist line is in progress
FUNCTION WorklistLineIsInProgress(local_wl_key worklist.wl_key%TYPE)
RETURN BOOLEAN IS
	local_status_code	worklist.status_code%TYPE;
BEGIN
	local_status_code	:= func_wl_status_code(local_wl_key);

	return (local_status_code = const_in_progress);
END WorklistLineIsInProgress;


-- Queues a deletion operation to the AALWRKQ
PROCEDURE QueueDeleteToAALWRKQ(
	p_PoDstNumber		IN aalwrkq.po_dst_number%TYPE,
	p_BoNumber		IN aalwrkq.bo_number%TYPE,
  p_RcvNumber  IN aalwrkq.receiver_number%TYPE,
  p_VendorPackID IN aalwrkq.vendor_pack%TYPE,
	p_StyleMasterSku	IN aalwrkq.style_master_sku%TYPE,
	p_ColorNumber		IN aalwrkq.color_number%TYPE,
	p_SizeNbr		IN aalwrkq.size_number%TYPE,
	p_DimensionNbr		IN aalwrkq.dimension_number%TYPE)
AS
BEGIN
	INSERT INTO aalwrkq (operation_code,	po_dst_number,
			     bo_number, receiver_number,vendor_pack, style_master_sku,
			     color_number,	size_number, dimension_number)
		     VALUES ('3', 		p_PoDstNumber,
			     p_BoNumber, p_RcvNumber, p_VendorPackID, 	p_StyleMasterSku,
			     p_ColorNumber,	p_SizeNbr, p_DimensionNbr);
END QueueDeleteToAALWRKQ;


PROCEDURE PutWorklistLineIntoDiscrepancy(local_wl_key worklist.wl_key%TYPE) IS
BEGIN
	UPDATE	worklist
	   SET	status_code	= const_descrepancy,
			status_desc	= 'Discrepancy'
	 WHERE	alloc_nbr IN (SELECT	alloc_nbr
							FROM	worklist
						   WHERE	wl_key	= local_wl_key);
END PutWorklistLineIntoDiscrepancy;


/************************************************************************
 * List Source Queries...												*
 ************************************************************************/
--FUNCTION func_style_name (
--	dept_nbr_src		IN NUMBER,
--	subdept_nbr_src		IN NUMBER,
--	class_nbr_src		IN NUMBER,
--    item_group_nbr_src   IN NUMBER,
--	subclass_nbr_src	IN NUMBER,
--    choice_nbr_src      IN NUMBER,
--	style_master_sku_src			IN NUMBER
--) RETURN VARCHAR2 IS
--	v_GroupTable	AllocMMS.t_FieldNamesArray;
--BEGIN
--	v_GroupTable.DELETE;
--	v_GroupTable(1)	:= NVL(dept_nbr_src, 0);
--	v_GroupTable(2)	:= NVL(subdept_nbr_src, 0);
--	v_GroupTable(3)	:= NVL(class_nbr_src, 0);
--    v_GroupTable(4)    := NVL(item_group_nbr_src, 0);
--	v_GroupTable(5)	:= NVL(subclass_nbr_src, 0);
--    v_GroupTable(6)    := NVL(choice_nbr_src, 0);
--	v_GroupTable(7)	:= NVL(style_master_sku_src, 0);
--
--	RETURN AllocMMS.GetListname(7, v_GroupTable);
--END func_style_name;

FUNCTION func_style_name (
    dept_nbr_src              IN list_sku.dept_nbr%TYPE,
    subdept_nbr_src         IN list_sku.subdept_nbr%TYPE,
    class_nbr_src             IN list_sku.class_nbr%TYPE,
    item_group_nbr_src      IN   list_sku.item_group_nbr%TYPE,
    subclass_nbr_src        IN list_sku.subclass_nbr%TYPE,
    choice_nbr_src          IN  list_sku.choice_nbr%TYPE,
    style_master_sku_src  IN list_sku.style_master_sku%TYPE)
   RETURN list_sku.product_name%TYPE IS
    new_product_name worklist.product_name%TYPE;
BEGIN
    SELECT rtrim(product_name)
    INTO new_product_name
    FROM list_sku
    WHERE dept_nbr = dept_nbr_src
    and subdept_nbr = subdept_nbr_src
    and class_nbr = class_nbr_src
    and item_group_nbr =item_group_nbr_src
    and subclass_nbr= subclass_nbr_src
    and choice_nbr  =choice_nbr_src
    and style_master_sku = style_master_sku_src;

    RETURN new_product_name;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        RETURN NULL;

END func_style_name;
FUNCTION func_product_nbr (style_master_sku_src in list_sku.style_master_sku%TYPE)
RETURN list_sku.product_nbr%TYPE IS
	new_product_nbr worklist.product_nbr%TYPE;
BEGIN
	SELECT product_nbr
	INTO new_product_nbr
	FROM list_sku
	WHERE style_master_sku = style_master_sku_src;

	RETURN new_product_nbr;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RETURN NULL;

END func_product_nbr;



FUNCTION func_color_name (color_nbr_src IN VARCHAR2)
RETURN VARCHAR2 IS
	v_GroupTable	AllocMMS.t_FieldNamesArray;
BEGIN
	v_GroupTable.DELETE;
	v_GroupTable(6)	:= color_nbr_src;

	RETURN AllocMMS.GetListName(6, v_GroupTable);
END func_color_name;


FUNCTION func_size_name (size_nbr_src IN VARCHAR2)
RETURN VARCHAR2 IS
	v_GroupTable	AllocMMS.t_FieldNamesArray;
BEGIN
	v_GroupTable.DELETE;
	v_GroupTable(7)	:= size_nbr_src;

	RETURN AllocMMS.GetListName(7, v_GroupTable);
END func_size_name;


FUNCTION func_dimension_name (dimension_nbr_src IN VARCHAR2)
RETURN VARCHAR2 IS
	v_GroupTable	AllocMMS.t_FieldNamesArray;
BEGIN
	v_GroupTable.DELETE;
	v_GroupTable(8)	:= dimension_nbr_src;

	RETURN AllocMMS.GetListName(8, v_GroupTable);
END func_dimension_name;


FUNCTION func_merch_status_name (merch_status_nbr_src IN NUMBER)
RETURN VARCHAR2 IS
	new_merch_status_name	merch_status_name.status_desc%TYPE;
BEGIN
	SELECT	status_desc
	  INTO	new_merch_status_name
	  FROM	merch_status_name
	 WHERE	status_code = merch_status_nbr_src;

	RETURN new_merch_status_name;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		RETURN (' ');
END func_merch_status_name;



/************************************************************************
 * Shape Table to Worklist data summing...                              *
 * -On Order Balance sums to WL                                         *
 * -Avail total qty sums to WL (and checks for discrepancies)           *
 * -Nbr of packs sums to WL for non-vendor packs                        *
 * -Qty per pack sums to WL for vendor packs                            *
 ************************************************************************/
PROCEDURE sum_oob (wl_in IN NUMBER) IS
/*sum_oob sums all appropriate data from Shape to WL except for available qty */
	v_bDidSum	BOOLEAN;
	vendor_packid	worklist.vendor_pack_id%TYPE;
BEGIN
	v_bDidSum := AllocMMS.SumColumnFromShapeToWorklist('ON_ORDER_BALANCE', wl_in);

        SELECT	VENDOR_PACK_ID
	  INTO	vendor_packid
	  FROM	worklist
	 WHERE	wl_key	= wl_in;

        IF (vendor_packid IS NULL) THEN
        	-- For a vendor pack (one per WL key), the same number of packs is used for each detail record.
        	-- The number from any of the detail records will be correct
	        v_bDidSum := AllocMMS.SumColumnFromShapeToWorklist('NBR_PACKS', wl_in);
	ELSE /*vendor pack*/
		-- On the other hand, the qty per pack on the WorkList should represent the total pack size for a vendor pack.
		-- The qty per pack sums to the WL for a vendor pre-pack, as every shape table record for a WL
		-- key is part of the one pack on that WL record
		v_bDidSum := AllocMMS.SumColumnFromShapeToWorklist('QTY_PER_PACK', wl_in);
	END IF;


END sum_oob;


PROCEDURE sum_avail (wl_in IN NUMBER) IS
/* sum_avail sums the available quantity column and checks for discrepancies when necessary*/
	new_qty		worklist.avail_qty%TYPE;
	old_qty		worklist.avail_qty%TYPE;
	old_status	worklist.status_code%TYPE;

	v_bDidSum	BOOLEAN;
BEGIN
	SELECT	status_code
	  INTO	old_status
	  FROM	worklist
	 WHERE	wl_key	= wl_in;

	IF old_status IN (const_approved, const_unapproved) THEN
		SELECT	NVL(avail_qty, 0)
		  INTO	old_qty
		  FROM	worklist
		 WHERE	wl_key	= wl_in;
	END IF;

	v_bDidSum	:= AllocMMS.SumColumnFromShapeToWorklist('AVAIL_QTY', wl_in);

	IF old_status IN (const_approved, const_unapproved) THEN
		SELECT	NVL(avail_qty, 0)
		  INTO	new_qty
		  FROM	worklist
		 WHERE	wl_key	= wl_in;
	END IF;

	IF (old_status IN (const_approved, const_unapproved)) AND (old_qty <> new_qty) THEN
		PutWorklistLineIntoDiscrepancy(wl_in);
		COMMIT;
	END IF;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		UPDATE	worklist
		   SET	avail_qty	= 0
		 WHERE	wl_key		= wl_in;

		IF (old_status IN (const_approved, const_unapproved)) AND (old_qty <> 0) THEN
			PutWorklistLineIntoDiscrepancy(wl_in);
			COMMIT;
		END IF;
END sum_avail;



/************************************************************************
 * Rebuilding Attribute Tables...										*
 ************************************************************************/
PROCEDURE RebuildUpdateAttributeTable (
	p_bRebuild		IN BOOLEAN		DEFAULT FALSE) AS
PRAGMA AUTONOMOUS_TRANSACTION;
	c_rCursor			t_rCursor;
	v_arrTargetTable	VARCHAR2(30);
	v_arrSourceTable	VARCHAR2(30);
	v_arrCodeColumn		VARCHAR2(50);
	v_arrDescColumn		VARCHAR2(50);
	v_arrAttribCode		VARCHAR2(50);	-- Code column name on the target table.
	v_arrAttribDesc		VARCHAR2(50);	-- Description column name on the target table.
	v_arrOperColumn		VARCHAR2(20)	:= 'operation_code';
	v_arrOperator		VARCHAR2(1);
	v_arrCode			VARCHAR2(5);
	v_arrDescription	VARCHAR2(25);
	v_arrStatusError	log_table.status%TYPE	:= 'Attribute Table not Rebuilt.';
	v_arrProcName		VARCHAR2(30)			:= 'RebuildUpdateAttributeTable';
	v_bTableTruncated	BOOLEAN;

	v_arrCursorStmt		VARCHAR2(275);
	v_arrDeleteStmt		VARCHAR2(150);
	v_arrUpdateStmt		VARCHAR2(250);
	v_arrInsertStmt		VARCHAR2(250);
BEGIN
	-- What table are we supposed to rebuild?
	v_arrTargetTable	:= 'attribute_cgr';
	v_arrSourceTable	:= 'aalcgr';
	v_arrCodeColumn		:= 'coord_group_code';
	v_arrDescColumn		:= 'coord_group_desc';
	v_arrAttribCode		:= 'coord_group_code';
	v_arrAttribDesc		:= 'coord_group_name';

	-- Do we have a table name?
	IF v_arrTargetTable IS NULL THEN
		LogError(v_arrStatusError, v_arrProcname || ': Either the source table name or the target table name was null.');
		RETURN;
	END IF;

	v_arrDeleteStmt	:= 'DELETE FROM ' || v_arrTargetTable || v_LF ||
					   ' WHERE ' || v_arrAttribCode || ' = :OpCode';
	v_arrUpdateStmt	:= 'UPDATE ' || v_arrTargetTable || v_LF ||
					   '   SET ' || v_arrAttribDesc|| ' = :AttrDesc' || v_LF ||
					   ' WHERE ' || v_arrAttribCode || ' = :AttrCode';
	v_arrInsertStmt	:= 'INSERT INTO ' || v_arrTargetTable || '(' || v_arrAttribCode || ', ' || v_arrAttribDesc|| ') ' || v_LF ||
					   '     VALUES (:AttrCode, :AttrDesc)';


	IF p_bRebuild THEN		-- We are to rebuild the table from scratch.
		v_bTableTruncated	:= AllocMMS.TruncateTable(v_arrTargetTable);

		-- Were we able to truncate the source table properly?
		IF v_arrTargetTable IS NULL THEN
			LogError(v_arrStatusError, v_arrProcname || ': Unable to truncate table ''' || v_arrTargetTable || '''.');
			RETURN;
		END IF;

		-- Re-add those which need to be.
		v_arrCursorStmt	:= 	'SELECT ' || v_arrOperColumn || ', ' || v_arrCodeColumn || ', ' || v_arrDescColumn || v_LF ||
							'  FROM ' || v_arrSourceTable || v_LF ||
							' WHERE ' || v_arrOperColumn || ' IN (1, 2)';

	ELSE					-- Just process the columns in the table.
		v_arrCursorStmt	:= 	'SELECT ' || v_arrOperColumn || ', ' || v_arrCodeColumn || ', ' || v_arrDescColumn || v_LF ||
							'  FROM ' || v_arrSourceTable;
	END IF;

	OPEN c_rCursor FOR v_arrCursorStmt;
	FETCH c_rCursor INTO v_arrOperator, v_arrCode, v_arrDescription;

	-- There was nothing for us to process, so just return...
	IF c_rCursor%NOTFOUND THEN
		IF c_rCursor%ISOPEN THEN
			CLOSE c_rCursor;
		END IF;

		RETURN;
	END IF;

	WHILE c_rCursor%FOUND LOOP
		-- Do we need to delete the item?
		IF TO_NUMBER(v_arrOperator) = 3 THEN
			EXECUTE IMMEDIATE
				v_arrDeleteStmt
				USING v_arrCode;
		ELSIF TO_NUMBER(v_arrOperator) IN (1, 2) THEN
			-- Okay, we want to try and update or insert the item.
			-- Assume the value already exists, and try to just update it.
			EXECUTE IMMEDIATE
				v_arrUpdateStmt
				USING v_arrDescription, v_arrCode;

			-- If the value didn't already exist, then insert it.
			IF SQL%NOTFOUND THEN
				EXECUTE IMMEDIATE
					v_arrInsertStmt
					USING v_arrCode, v_arrDescription;
			END IF;
		END IF;

		FETCH c_rCursor INTO v_arrOperator, v_arrCode, v_arrDescription;
	END LOOP;

	CLOSE c_rCursor;

	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		IF c_rCursor%ISOPEN THEN
			CLOSE c_rCursor;
		END IF;

		ROLLBACK;

		LogError(v_arrStatusError, v_arrProcname || ': Attribute group ''' || v_arrTargetTable || ''' was not rebuilt [' || SQLERRM || '].');

END RebuildUpdateAttributeTable;


PROCEDURE proc_aalcgr(p_bCalledForRebuild	IN BOOLEAN) AS
BEGIN
	RebuildUpdateAttributeTable(p_bCalledForRebuild);
END proc_aalcgr;


/************************************************************************
 * Rebuilding List Source Tables...										*
 ************************************************************************/
PROCEDURE proc_aaldpt(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_dept;

	INSERT INTO	list_dept(dept_nbr, dept_name)
		 SELECT	department_number, department_name
		   FROM	aaldpt
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aaldpt;


PROCEDURE proc_aalsdp(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_subdept;

	INSERT INTO	list_subdept(dept_nbr, subdept_nbr, subdept_name)
		 SELECT	department_number, subdepartment_number, subdepartment_name
		   FROM	aalsdp
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aalsdp;


PROCEDURE proc_aalcls(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_class;

	INSERT INTO	list_class(dept_nbr, subdept_nbr, class_nbr, class_name)
		 SELECT	department_number, subdepartment_number, class_number, class_name
		   FROM	aalcls
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aalcls;

PROCEDURE proc_aalitg(p_bCalledForRebuild    IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    DELETE FROM list_item_group;

    INSERT INTO    list_item_group(dept_nbr, subdept_nbr, class_nbr,item_group_nbr, item_group_name)
         SELECT    department_number, subdepartment_number, class_number,item_group_number, item_group_name
           FROM    aalitg
          WHERE operation_code IN ('1', '2');

    COMMIT;
END proc_aalitg;

PROCEDURE proc_aalscl(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_subclass;

	INSERT INTO	list_subclass(dept_nbr, subdept_nbr, class_nbr,item_group_nbr, subclass_nbr, subclass_name)
		 SELECT	department_number, subdepartment_number, class_number,item_group_number, subclass_number, subclass_name
		   FROM	aalscl
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aalscl;

PROCEDURE proc_aalchs(p_bCalledForRebuild    IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    DELETE FROM list_choice;

    INSERT INTO    list_choice(dept_nbr, subdept_nbr, class_nbr,item_group_nbr, subclass_nbr,choice_nbr, choice_name)
         SELECT    department_number, subdepartment_number, class_number,item_group_number, subclass_number,choice_number, choice_name
           FROM    aalchs
          WHERE operation_code IN ('1', '2');

    COMMIT;
END proc_aalchs;

PROCEDURE proc_aalsty(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
	CURSOR cur_addupd IS
		SELECT	*
		  FROM	aalsty
		 WHERE	operation_code IN ('1', '2');

	CURSOR cur_vendor IS
		SELECT	DISTINCT style_vendor, vendor_description
		  FROM	aalsty
		 WHERE	style_vendor > 0
		   AND	operation_code IN ('1', '2');

	CURSOR cur_delete IS
		SELECT	*
		  FROM	aalsty
		 WHERE	operation_code IN ('3');

	key_count	PLS_INTEGER;
BEGIN
	INSERT INTO	list_vendor(vendor_nbr)
		(SELECT	style_vendor
		   FROM	aalsty
		  WHERE style_vendor IS NOT NULL
		MINUS
		 SELECT	vendor_nbr
		   FROM	list_vendor);

	FOR curr_rec IN cur_vendor LOOP
		UPDATE	list_vendor
		   SET	vendor_name	= curr_rec.vendor_description
		 WHERE	vendor_nbr	= curr_rec.style_vendor;
	END LOOP;

	COMMIT;

	FOR curr_rec IN cur_addupd LOOP
		SELECT	COUNT (*)
		  INTO	key_count
		  FROM	list_sku
		 WHERE	style_master_sku= TRIM(TO_CHAR(NVL(curr_rec.sku_number, 0),'00000000'));

		IF key_count < 1 THEN
		   INSERT INTO list_sku(dept_nbr,
		                        subdept_nbr,
		                        class_nbr,
                                item_group_nbr,
		                        subclass_nbr,
                                choice_nbr,
		                        style_master_sku)

		   VALUES  (NVL(curr_rec.department_number, 0),
		            NVL(curr_rec.subdepartment_number, 0),
		            NVL(curr_rec.class_number, 0),
                    NVL(curr_rec.item_group_number, 0),
		            NVL(curr_rec.subclass_number, 0),
                    NVL(curr_rec.choice_number, 0),
		            TRIM(TO_CHAR(NVL(curr_rec.sku_number, 0),'00000000'))
		            );
		END IF;

		UPDATE	list_sku
		   SET	VENDOR_NBR	= CURR_REC.STYLE_VENDOR,
			product_name	= rtrim(curr_rec.style_description),
			product_nbr	= curr_rec.style_number,
			dept_nbr	= NVL(curr_rec.department_number, 0),
		   	subdept_nbr	= NVL(curr_rec.subdepartment_number, 0),
		   	class_nbr	= NVL(curr_rec.class_number, 0),
            item_group_nbr    = NVL(curr_rec.item_group_number, 0),
		   	subclass_nbr	= NVL(curr_rec.subclass_number, 0),
            choice_nbr      =NVL(curr_rec.choice_number ,0)
		 WHERE	style_master_sku= TRIM(TO_CHAR(NVL(curr_rec.sku_number, 0),'00000000'));
	END LOOP;

	FOR curr_rec IN cur_delete LOOP
		DELETE	list_sku
		 WHERE	style_master_sku	= TRIM(TO_CHAR(NVL(curr_rec.sku_number, 0),'00000000'));
	END LOOP;

	COMMIT;
END proc_aalsty;


PROCEDURE proc_aalcol(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_color;

	INSERT INTO	list_color(color_nbr, color_name)
		 SELECT	color_code, color_description
		   FROM	aalcol
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aalcol;


PROCEDURE proc_aalsiz(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_size;

	INSERT INTO	list_size(size_nbr, size_name)
		 SELECT	size_code, size_description
		   FROM	aalsiz
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aalsiz;


PROCEDURE proc_aaldim(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	DELETE FROM list_dim;

	INSERT INTO	list_dim(dim_nbr, dim_name)
		 SELECT	dimension_code, dimension_desc
		   FROM	aaldim
		  WHERE operation_code IN ('1', '2');

	COMMIT;
END proc_aaldim;



/************************************************************************
 * (Re)building History (Staging) Data...								*
 ************************************************************************/
/* Following procedure proc_aalaph has been modified by Abhi Sharma (JDA Software):
   - Added attribute columns - ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes.
   - Modified the logic to include Regular Sales Columns - REG_SLS_01AG0 through
     REG_SLS_78AGO as per the CR changes.
*/
PROCEDURE proc_aalaph(p_bCalledForRebuild	IN BOOLEAN) AS
  -- Table space names
  stageDimensionTablespaceName user_tables.tablespace_name%TYPE;

  -- Saved DDL to recreate indexes for the STAGE_DIMENSION table.
  ddlForStage_Dimension AllocMMS.DDL_tabType;

  -- Extent information for the STAGE_DIMENSION table.
--  stageDimensionInitialExtent PLS_INTEGER;
--  stageDimensionNextExtent PLS_INTEGER;
--  stageDimensionMinExtent PLS_INTEGER;
--  stageDimensionMaxExtent PLS_INTEGER;
--  stageDimensionPctIncrease PLS_INTEGER;

-- Extent information for the STAGE_SUBCLASS table.
   stageDimensionInitialExtent user_tables.initial_extent%TYPE;
  stageDimensionNextExtent    user_tables.next_extent%TYPE;
  stageDimensionMinExtent    user_tables.min_extents%TYPE;
  stageDimensionMaxExtent     user_tables.max_extents%TYPE;
  stageDimensionPctIncrease   user_tables.pct_increase%TYPE;
  StageDimensionIOTType       user_tables.iot_type%TYPE;

  strstageDimensionNextExtent VARCHAR2(30);
  strstageDimensionPctIncrease VARCHAR2(30);

BEGIN
  -- Get the tablespace of the STAGE_DIMENSION table.
  stageDimensionTablespaceName := GetTableSpaceName('STAGE_DIMENSION');

  -- Check for a good tablespace name
  IF stageDimensionTablespaceName IS NULL THEN
    LogError('', 'proc_aalaph : Unable to determine the tablespace name for the stage_dimension table');
    RETURN;
  END IF;

  -- Get the extent information for the STAGE_DIMENSION table.
  IF NOT Getextentinfo( 'STAGE_DIMENSION', stageDimensionInitialExtent, stageDimensionNextExtent, stageDimensionMinExtent, stageDimensionMaxExtent, stageDimensionPctIncrease ) THEN
    LogError('', 'proc_aalaph : Unable to determine the table extents for the stage_dimension table');
    RETURN;
  END IF;

  -- Omit NEXT if Next_Extent is not explicitly specified
  IF stageDimensionNextExtent IS NULL THEN
    strstageDimensionNextExtent := '';
  ELSE
    strstageDimensionNextExtent := ' NEXT ' || stageDimensionNextExtent;
  END IF;

  -- Omit PCTINCREASE if it is not explicitly specified
  IF stageDimensionPctIncrease IS NULL THEN
    strstageDimensionPctIncrease := '';
  ELSE
    strstageDimensionPctIncrease := ' PCTINCREASE ' || stageDimensionPctIncrease;
  END IF;

  -- Grab the DDL for the indexes, etc. before we rename,
  ddlForStage_Dimension := GetTableIndexAndKeyDDL('STAGE_DIMENSION');

  -- Rename the old table as a backup before the load
  EXECUTE IMMEDIATE 'rename STAGE_DIMENSION to ' || OLD_STAGE_DIMENSION_TABLE_NAME;

  EXECUTE IMMEDIATE 'CREATE TABLE ' ||
    'STAGE_DIMENSION ' ||
    'NOLOGGING ' ||
    'TABLESPACE	' ||
    stageDimensionTablespaceName ||
    ' STORAGE (' ||
    ' INITIAL ' || stageDimensionInitialExtent ||
    strstageDimensionNextExtent ||
    ' MINEXTENTS ' || stageDimensionMinExtent ||
    ' MAXEXTENTS ' || stageDimensionMaxExtent ||
    strstageDimensionPctIncrease || ') ' ||
    'AS ' ||
    'select  ' ||
    'location_number        LOCATION_ID, ' ||
    'department_number    DEPT_NBR, ' ||
    'subdepartment_number    SUBDEPT_NBR, ' ||
    'class_number		CLASS_NBR, ' ||
    'item_group_number        ITEM_GROUP_NBR, ' ||
    'subclass_number            SUBCLASS_NBR, ' ||
    'CHOICE_NUMBER   CHOICE_NBR,' ||
    'NVL(master_sku,0)    STYLE_MASTER_SKU, ' ||
    'NVL(color_code,0)	COLOR_NBR, ' ||
    'size_code                SIZE_NBR, ' ||
    'dimension_code		DIM_NBR, ' ||
    '0                WTD_SALES, ' ||
    '0                ON_HAND_CURR, ' ||
    '0                DNF_INTRANSIT, ' ||
    '0                STR_ON_ORDER,  ' ||
    'on_hand_01_ago		ON_HAND_01AGO, ' ||
    'on_hand_02_ago		ON_HAND_02AGO, ' ||
    'on_hand_03_ago		ON_HAND_03AGO, ' ||
    'on_hand_04_ago		ON_HAND_04AGO, ' ||
    'on_hand_05_ago		ON_HAND_05AGO, ' ||
    'on_hand_06_ago		ON_HAND_06AGO, ' ||
    'on_hand_07_ago		ON_HAND_07AGO, ' ||
    'on_hand_08_ago		ON_HAND_08AGO, ' ||
    'on_hand_09_ago		ON_HAND_09AGO, ' ||
    'on_hand_10_ago		ON_HAND_10AGO, ' ||
    'on_hand_11_ago		ON_HAND_11AGO, ' ||
    'on_hand_12_ago		ON_HAND_12AGO, ' ||
    'on_hand_13_ago		ON_HAND_13AGO, ' ||
    'on_hand_14_ago		ON_HAND_14AGO, ' ||
    'on_hand_15_ago		ON_HAND_15AGO, ' ||
    'on_hand_16_ago		ON_HAND_16AGO, ' ||
    'on_hand_17_ago		ON_HAND_17AGO, ' ||
    'on_hand_18_ago		ON_HAND_18AGO, ' ||
    'on_hand_19_ago		ON_HAND_19AGO, ' ||
    'on_hand_20_ago		ON_HAND_20AGO, ' ||
    'on_hand_21_ago		ON_HAND_21AGO, ' ||
    'on_hand_22_ago		ON_HAND_22AGO, ' ||
    'on_hand_23_ago		ON_HAND_23AGO, ' ||
    'on_hand_24_ago		ON_HAND_24AGO, ' ||
    'on_hand_25_ago		ON_HAND_25AGO, ' ||
    'on_hand_26_ago		ON_HAND_26AGO, ' ||
    'on_hand_27_ago		ON_HAND_27AGO, ' ||
    'on_hand_28_ago		ON_HAND_28AGO, ' ||
    'on_hand_29_ago		ON_HAND_29AGO, ' ||
    'on_hand_30_ago		ON_HAND_30AGO, ' ||
    'on_hand_31_ago		ON_HAND_31AGO, ' ||
    'on_hand_32_ago		ON_HAND_32AGO, ' ||
    'on_hand_33_ago		ON_HAND_33AGO, ' ||
    'on_hand_34_ago		ON_HAND_34AGO, ' ||
    'on_hand_35_ago		ON_HAND_35AGO, ' ||
    'on_hand_36_ago		ON_HAND_36AGO, ' ||
    'on_hand_37_ago		ON_HAND_37AGO, ' ||
    'on_hand_38_ago		ON_HAND_38AGO, ' ||
    'on_hand_39_ago		ON_HAND_39AGO, ' ||
    'on_hand_40_ago		ON_HAND_40AGO, ' ||
    'on_hand_41_ago		ON_HAND_41AGO, ' ||
    'on_hand_42_ago		ON_HAND_42AGO, ' ||
    'on_hand_43_ago		ON_HAND_43AGO, ' ||
    'on_hand_44_ago		ON_HAND_44AGO, ' ||
    'on_hand_45_ago		ON_HAND_45AGO, ' ||
    'on_hand_46_ago		ON_HAND_46AGO, ' ||
    'on_hand_47_ago		ON_HAND_47AGO, ' ||
    'on_hand_48_ago		ON_HAND_48AGO, ' ||
    'on_hand_49_ago		ON_HAND_49AGO, ' ||
    'on_hand_50_ago		ON_HAND_50AGO, ' ||
    'on_hand_51_ago		ON_HAND_51AGO, ' ||
    'on_hand_52_ago		ON_HAND_52AGO, ' ||
    'on_hand_53_ago		ON_HAND_53AGO, ' ||
    'on_hand_54_ago		ON_HAND_54AGO, ' ||
    'on_hand_55_ago		ON_HAND_55AGO, ' ||
    'on_hand_56_ago		ON_HAND_56AGO, ' ||
    'on_hand_57_ago		ON_HAND_57AGO, ' ||
    'on_hand_58_ago		ON_HAND_58AGO, ' ||
    'on_hand_59_ago		ON_HAND_59AGO, ' ||
    'on_hand_60_ago		ON_HAND_60AGO, ' ||
    'on_hand_61_ago		ON_HAND_61AGO, ' ||
    'on_hand_62_ago     ON_HAND_62AGO, ' ||
    'on_hand_63_ago     ON_HAND_63AGO, ' ||
    'on_hand_64_ago     ON_HAND_64AGO, ' ||
    'on_hand_65_ago     ON_HAND_65AGO, ' ||
    'on_hand_66_ago     ON_HAND_66AGO, ' ||
    'on_hand_67_ago     ON_HAND_67AGO, ' ||
    'on_hand_68_ago     ON_HAND_68AGO, ' ||
    'on_hand_69_ago     ON_HAND_69AGO, ' ||
    'on_hand_70_ago     ON_HAND_70AGO, ' ||
    'on_hand_71_ago     ON_HAND_71AGO, ' ||
    'on_hand_72_ago     ON_HAND_72AGO, ' ||
    'on_hand_73_ago     ON_HAND_73AGO, ' ||
    'on_hand_74_ago     ON_HAND_74AGO, ' ||
    'on_hand_75_ago     ON_HAND_75AGO, ' ||
    'on_hand_76_ago     ON_HAND_76AGO, ' ||
    'on_hand_77_ago     ON_HAND_77AGO, ' ||
    'on_hand_78_ago     ON_HAND_78AGO, ' ||
    'sales_01_ago		SLS_01AGO, ' ||
    'sales_02_ago		SLS_02AGO, ' ||
    'sales_03_ago		SLS_03AGO, ' ||
    'sales_04_ago		SLS_04AGO, ' ||
    'sales_05_ago		SLS_05AGO, ' ||
    'sales_06_ago		SLS_06AGO, ' ||
    'sales_07_ago		SLS_07AGO, ' ||
    'sales_08_ago		SLS_08AGO, ' ||
    'sales_09_ago		SLS_09AGO, ' ||
    'sales_10_ago		SLS_10AGO, ' ||
    'sales_11_ago		SLS_11AGO, ' ||
    'sales_12_ago		SLS_12AGO, ' ||
    'sales_13_ago		SLS_13AGO, ' ||
    'sales_14_ago		SLS_14AGO, ' ||
    'sales_15_ago		SLS_15AGO, ' ||
    'sales_16_ago		SLS_16AGO, ' ||
    'sales_17_ago		SLS_17AGO, ' ||
    'sales_18_ago		SLS_18AGO, ' ||
    'sales_19_ago		SLS_19AGO, ' ||
    'sales_20_ago		SLS_20AGO, ' ||
    'sales_21_ago		SLS_21AGO, ' ||
    'sales_22_ago		SLS_22AGO, ' ||
    'sales_23_ago		SLS_23AGO, ' ||
    'sales_24_ago		SLS_24AGO, ' ||
    'sales_25_ago		SLS_25AGO, ' ||
    'sales_26_ago		SLS_26AGO, ' ||
    'sales_27_ago		SLS_27AGO, ' ||
    'sales_28_ago		SLS_28AGO, ' ||
    'sales_29_ago		SLS_29AGO, ' ||
    'sales_30_ago		SLS_30AGO, ' ||
    'sales_31_ago		SLS_31AGO, ' ||
    'sales_32_ago		SLS_32AGO, ' ||
    'sales_33_ago		SLS_33AGO, ' ||
    'sales_34_ago		SLS_34AGO, ' ||
    'sales_35_ago		SLS_35AGO, ' ||
    'sales_36_ago		SLS_36AGO, ' ||
    'sales_37_ago		SLS_37AGO, ' ||
    'sales_38_ago		SLS_38AGO, ' ||
    'sales_39_ago		SLS_39AGO, ' ||
    'sales_40_ago		SLS_40AGO, ' ||
    'sales_41_ago		SLS_41AGO, ' ||
    'sales_42_ago		SLS_42AGO, ' ||
    'sales_43_ago		SLS_43AGO, ' ||
    'sales_44_ago		SLS_44AGO, ' ||
    'sales_45_ago		SLS_45AGO, ' ||
    'sales_46_ago		SLS_46AGO, ' ||
    'sales_47_ago		SLS_47AGO, ' ||
    'sales_48_ago		SLS_48AGO, ' ||
    'sales_49_ago		SLS_49AGO, ' ||
    'sales_50_ago		SLS_50AGO, ' ||
    'sales_51_ago		SLS_51AGO, ' ||
    'sales_52_ago		SLS_52AGO, ' ||
    'sales_53_ago		SLS_53AGO, ' ||
    'sales_54_ago		SLS_54AGO, ' ||
    'sales_55_ago		SLS_55AGO, ' ||
    'sales_56_ago		SLS_56AGO, ' ||
    'sales_57_ago		SLS_57AGO, ' ||
    'sales_58_ago		SLS_58AGO, ' ||
    'sales_59_ago		SLS_59AGO, ' ||
    'sales_60_ago		SLS_60AGO, ' ||
    'sales_61_ago		SLS_61AGO, ' ||
    'sales_62_ago		SLS_62AGO, ' ||
    'sales_63_ago		SLS_63AGO, ' ||
    'sales_64_ago		SLS_64AGO, ' ||
    'sales_65_ago		SLS_65AGO, ' ||
    'sales_66_ago		SLS_66AGO, ' ||
    'sales_67_ago		SLS_67AGO, ' ||
    'sales_68_ago		SLS_68AGO, ' ||
    'sales_69_ago		SLS_69AGO, ' ||
    'sales_70_ago		SLS_70AGO, ' ||
    'sales_71_ago		SLS_71AGO, ' ||
    'sales_72_ago		SLS_72AGO, ' ||
    'sales_73_ago		SLS_73AGO, ' ||
    'sales_74_ago		SLS_74AGO, ' ||
    'sales_75_ago		SLS_75AGO, ' ||
    'sales_76_ago		SLS_76AGO, ' ||
    'sales_77_ago		SLS_77AGO, ' ||
    'sales_78_ago		SLS_78AGO, ' ||
    'sysdate            LASTROLL, ' ||
    'attr_1_code        ATTR_1_CODE,  ' ||
    'attr_2_code        ATTR_2_CODE,  ' ||
    'attr_3_code        ATTR_3_CODE,  ' ||
    'attr_4_code        ATTR_4_CODE,  ' ||
    'attr_5_code        ATTR_5_CODE,  ' ||
    'attr_6_code        ATTR_6_CODE,  ' ||
    'attr_7_code        ATTR_7_CODE,  ' ||
    'attr_8_code        ATTR_8_CODE,  ' ||
    'attr_9_code        ATTR_9_CODE,  ' ||
    'attr_10_code       ATTR_10_CODE,  ' ||
    'attr_11_code       ATTR_11_CODE,  ' ||
    'attr_12_code       ATTR_12_CODE,  ' ||
    '0                  REG_SLS_WTD, ' ||
    'reg_sls_01ago      REG_SLS_01AGO, ' ||
    'reg_sls_02ago      REG_SLS_02AGO,  ' ||
    'reg_sls_03ago      REG_SLS_03AGO,  ' ||
    'reg_sls_04ago      REG_SLS_04AGO,  ' ||
    'reg_sls_05ago      REG_SLS_05AGO,  ' ||
    'reg_sls_06ago      REG_SLS_06AGO,  ' ||
    'reg_sls_07ago      REG_SLS_07AGO,  ' ||
    'reg_sls_08ago      REG_SLS_08AGO,  ' ||
    'reg_sls_09ago      REG_SLS_09AGO,  ' ||
    'reg_sls_10ago      REG_SLS_10AGO,  ' ||
    'reg_sls_11ago      REG_SLS_11AGO,  ' ||
    'reg_sls_12ago      REG_SLS_12AGO,  ' ||
    'reg_sls_13ago      REG_SLS_13AGO,  ' ||
    'reg_sls_14ago      REG_SLS_14AGO,  ' ||
    'reg_sls_15ago      REG_SLS_15AGO,  ' ||
    'reg_sls_16ago      REG_SLS_16AGO,  ' ||
    'reg_sls_17ago      REG_SLS_17AGO,  ' ||
    'reg_sls_18ago      REG_SLS_18AGO,  ' ||
    'reg_sls_19ago      REG_SLS_19AGO,  ' ||
    'reg_sls_20ago      REG_SLS_20AGO,  ' ||
    'reg_sls_21ago      REG_SLS_21AGO,  ' ||
    'reg_sls_22ago      REG_SLS_22AGO,  ' ||
    'reg_sls_23ago      REG_SLS_23AGO,  ' ||
    'reg_sls_24ago      REG_SLS_24AGO,  ' ||
    'reg_sls_25ago      REG_SLS_25AGO,  ' ||
    'reg_sls_26ago      REG_SLS_26AGO,  ' ||
    'reg_sls_27ago      REG_SLS_27AGO,  ' ||
    'reg_sls_28ago      REG_SLS_28AGO,  ' ||
    'reg_sls_29ago      REG_SLS_29AGO,  ' ||
    'reg_sls_30ago      REG_SLS_30AGO,  ' ||
    'reg_sls_31ago      REG_SLS_31AGO,  ' ||
    'reg_sls_32ago      REG_SLS_32AGO,  ' ||
    'reg_sls_33ago      REG_SLS_33AGO,  ' ||
    'reg_sls_34ago      REG_SLS_34AGO,  ' ||
    'reg_sls_35ago      REG_SLS_35AGO,  ' ||
    'reg_sls_36ago      REG_SLS_36AGO,  ' ||
    'reg_sls_37ago      REG_SLS_37AGO,  ' ||
    'reg_sls_38ago      REG_SLS_38AGO,  ' ||
    'reg_sls_39ago      REG_SLS_39AGO,  ' ||
    'reg_sls_40ago      REG_SLS_40AGO,  ' ||
    'reg_sls_41ago      REG_SLS_41AGO,  ' ||
    'reg_sls_42ago      REG_SLS_42AGO,  ' ||
    'reg_sls_43ago      REG_SLS_43AGO,  ' ||
    'reg_sls_44ago      REG_SLS_44AGO,  ' ||
    'reg_sls_45ago      REG_SLS_45AGO,  ' ||
    'reg_sls_46ago      REG_SLS_46AGO,  ' ||
    'reg_sls_47ago      REG_SLS_47AGO,  ' ||
    'reg_sls_48ago      REG_SLS_48AGO,  ' ||
    'reg_sls_49ago      REG_SLS_49AGO,  ' ||
    'reg_sls_50ago      REG_SLS_50AGO,  ' ||
    'reg_sls_51ago      REG_SLS_51AGO,  ' ||
    'reg_sls_52ago      REG_SLS_52AGO,  ' ||
    'reg_sls_53ago      REG_SLS_53AGO,  ' ||
    'reg_sls_54ago      REG_SLS_54AGO,  ' ||
    'reg_sls_55ago      REG_SLS_55AGO,  ' ||
    'reg_sls_56ago      REG_SLS_56AGO,  ' ||
    'reg_sls_57ago      REG_SLS_57AGO,  ' ||
    'reg_sls_58ago      REG_SLS_58AGO,  ' ||
    'reg_sls_59ago      REG_SLS_59AGO,  ' ||
    'reg_sls_60ago      REG_SLS_60AGO,  ' ||
    'reg_sls_61ago      REG_SLS_61AGO,  ' ||
    'reg_sls_62ago      REG_SLS_62AGO,  ' ||
    'reg_sls_63ago      REG_SLS_63AGO,  ' ||
    'reg_sls_64ago      REG_SLS_64AGO,  ' ||
    'reg_sls_65ago      REG_SLS_65AGO,  ' ||
    'reg_sls_66ago      REG_SLS_66AGO,  ' ||
    'reg_sls_67ago      REG_SLS_67AGO,  ' ||
    'reg_sls_68ago      REG_SLS_68AGO,  ' ||
    'reg_sls_69ago      REG_SLS_69AGO,  ' ||
    'reg_sls_70ago      REG_SLS_70AGO,  ' ||
    'reg_sls_71ago      REG_SLS_71AGO,  ' ||
    'reg_sls_72ago      REG_SLS_72AGO,  ' ||
    'reg_sls_73ago      REG_SLS_73AGO,  ' ||
    'reg_sls_74ago      REG_SLS_74AGO,  ' ||
    'reg_sls_75ago      REG_SLS_75AGO,  ' ||
    'reg_sls_76ago      REG_SLS_76AGO,  ' ||
    'reg_sls_77ago      REG_SLS_77AGO,  ' ||
    'reg_sls_78ago      REG_SLS_78AGO   ' ||
    'from aalaph ';


  AllocMMS.RebuildStageSubclass;
  AllocMMS.RebuildStageclass;

  EXECUTE IMMEDIATE 'drop TABLE ' || OLD_STAGE_DIMENSION_TABLE_NAME;

  -- recreate the indexes for the stage_dimension table.
  BEGIN
    AllocMMS.ExecutedIndexAndKeyDDL(ddlForStage_Dimension);

  EXCEPTION
     WHEN OTHERS THEN
          LogError('', 'proc_aalaph : Unable to recreate index(es) for the STAGE_DIMENSION table.  Any indexes will have to be manually created.');
     RAISE;
  END;


EXCEPTION

  WHEN OTHERS THEN

  IF Tableexists(OLD_STAGE_DIMENSION_TABLE_NAME) THEN
    IF TableExists('STAGE_DIMENSION') THEN
       EXECUTE IMMEDIATE 'drop table STAGE_DIMENSION';
    END IF;
    EXECUTE IMMEDIATE 'rename ' || OLD_STAGE_DIMENSION_TABLE_NAME || ' to STAGE_DIMENSION';
  END IF;

  RAISE;  -- Reraise exception

END proc_aalaph;

/* Following procedure proc_aalapr has been modified by Abhi Sharma (JDA Software):
   - Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes.
   - Added a logic to handle the REG_SLS for Current and History weeks as per
     the CR changes.
*/
PROCEDURE proc_aalapr(p_bCalledForRebuild	IN BOOLEAN) AS
	CURSOR c_aalapr IS
		SELECT	location_number,	department_number,	subdepartment_number,
				class_number,	item_group_number,	subclass_number, choice_number,	NVL (color_code, 0) color_code,
				size_code,			dimension_code,		master_sku,
				year,				week,
				NVL (sales_quantity_prev, 0) sales_qty_prev,
				NVL (sales_quantity_curr, 0) sales_qty_curr,
				NVL (on_hand_quantity, 0) on_hand_qty,
				in_transit_quantity,
                NVL(on_order_quantity, 0) str_on_order,
                ATTR_1_CODE,
                ATTR_2_CODE,
                ATTR_3_CODE,
                ATTR_4_CODE,
                ATTR_5_CODE,
                ATTR_6_CODE,
                ATTR_7_CODE,
                ATTR_8_CODE,
                ATTR_9_CODE,
                ATTR_10_CODE,
                ATTR_11_CODE,
                ATTR_12_CODE,
                NVL (REG_SALES_QTY_CURR, 0) reg_sales_qty_curr,
                NVL (REG_SALES_QTY_PREV, 0) reg_sales_qty_prev
		  FROM	aalapr;

	chunk  CONSTANT PLS_INTEGER		:= 100000;
	record_no		PLS_INTEGER		:= 0;

	v_PreviousName	   VARCHAR2(50);
    v_PreviousName1    VARCHAR2(50);
	v_CurrentName	   VARCHAR2(50);
    v_CurrentName1     VARCHAR2(50);
	v_CurrentWeek	calendar.week_order%TYPE;
	v_weeksago		calendar.week_order%TYPE;
	v_PrevWeek		calendar.week_order%TYPE;

	v_arrSelectStmt		              VARCHAR2(4000);
	v_arrSelCountStmt	              VARCHAR2(4000);
	v_arrUpdateStmt		              VARCHAR2(4000);
	v_arrSubClause		              VARCHAR2(100);
	v_bTableTruncated	              BOOLEAN;
	v_KeyCount			              NUMBER;

	v_arrStatusError	log_table.status%TYPE	:= 'Daily History not updated.';
	v_arrProcName		VARCHAR2(35)			:= 'Proc_aalapr';
BEGIN

	COMMIT;

	-- To speed up removing records from log_table:
	v_bTableTruncated	:= AllocMMS.TruncateTable('log_table');

	IF NOT v_bTableTruncated THEN
		RoLLBACK;
		LogError(v_arrStatusError, v_arrProcname || ': Not able to truncate table ''log_table''.');
		RETURN;
	END IF;

	v_arrSelectStmt	:=
		'SELECT /*+ index(stage_dimension stage_dimension_idx) */ COUNT(*) ' || v_LF ||
		'  FROM stage_dimension ' || v_LF ||
		' WHERE location_id	= :LocID ' || v_LF ||
		'   AND dept_nbr	= :DeptNbr ' || v_LF ||
		'   AND subdept_nbr	= :SubDeptNbr ' || v_LF ||
		'   AND class_nbr	= :ClassNbr ' || v_LF ||
        '   AND Item_group_nbr    = :ItemGroupNbr ' || v_LF ||
		'   AND subclass_nbr= :SubClassNbr ' || v_LF ||
        '   AND choice_nbr= :ChoiceNbr ' || v_LF ||
		'   AND style_master_sku= :MasterSku ' || v_LF ||
		'   AND color_nbr	= :ColorCode';

	SELECT	week_order
	  INTO	v_CurrentWeek
	  FROM	calendar
	 WHERE	current_week = 'Y';

	FOR r_aalapr IN c_aalapr LOOP
		SELECT	(v_CurrentWeek - week_order)
		  INTO	v_weeksago
		  FROM	calendar
		 WHERE	year	= r_aalapr.year
		   AND	week	= r_aalapr.week;

		v_PrevWeek	:= v_weeksago + 1;

		-- Create the partial where statement for size and dimension. Also check to
		-- see if an entry already exists in the staging table for the given product.
		IF r_aalapr.size_code IS NULL THEN
			v_arrSubClause	:= '   AND size_nbr IS NULL ' || v_LF ||
							   '   AND dim_nbr IS NULL';
			v_arrSelCountStmt	:= v_arrSelectStmt || v_LF || v_arrSubClause;

			EXECUTE IMMEDIATE
				v_arrSelCountStmt
				INTO v_KeyCount
				USING r_aalapr.location_number,     r_aalapr.department_number,    r_aalapr.subdepartment_number,
                      r_aalapr.class_number,        r_aalapr.item_group_number,    r_aalapr.subclass_number,
                      r_aalapr.choice_number,       r_aalapr.master_sku,           r_aalapr.color_code;
		ELSIF r_aalapr.dimension_code IS NULL THEN
			v_arrSubClause	:= '   AND size_nbr = :size_code ' || v_LF ||
							   '   AND dim_nbr IS NULL';
			v_arrSelCountStmt	:= v_arrSelectStmt || v_LF || v_arrSubClause;

			EXECUTE IMMEDIATE
				v_arrSelCountStmt
				INTO v_KeyCount
				USING r_aalapr.location_number, r_aalapr.department_number, r_aalapr.subdepartment_number, r_aalapr.class_number,r_aalapr.item_group_number,
					  r_aalapr.subclass_number, r_aalapr.choice_number, r_aalapr.master_sku, r_aalapr.color_code, r_aalapr.size_code;
		ELSE
			v_arrSubClause	:= '   AND size_nbr = :size_code ' || v_LF ||
							   '   AND dim_nbr = :dimension_code';
			v_arrSelCountStmt	:= v_arrSelectStmt || v_LF || v_arrSubClause;

			EXECUTE IMMEDIATE
				v_arrSelCountStmt
				INTO v_KeyCount
				USING r_aalapr.location_number, r_aalapr.department_number, r_aalapr.subdepartment_number, r_aalapr.class_number, r_aalapr.item_group_number,
					  r_aalapr.subclass_number,r_aalapr.choice_number, r_aalapr.master_sku, r_aalapr.color_code, r_aalapr.size_code, r_aalapr.dimension_code;
		END IF;

		-- Insert the record if it doesn't already exist.
		IF v_KeyCount < 1 THEN
       -- Update the STAGE_DIMENSION table
       EXECUTE IMMEDIATE
				'INSERT INTO stage_dimension(location_id, dept_nbr, subdept_nbr, class_nbr,Item_group_nbr, ' || v_LF ||
				'             subclass_nbr,choice_nbr, style_master_sku, color_nbr, size_nbr, dim_nbr, dnf_intransit, str_on_order, ATTR_1_CODE, ATTR_2_CODE, ATTR_3_CODE, ATTR_4_CODE, ATTR_5_CODE, ATTR_6_CODE, ATTR_7_CODE, ATTR_8_CODE, ATTR_9_CODE, ATTR_10_CODE, ATTR_11_CODE, ATTR_12_CODE) ' || v_LF ||
				'     VALUES (:LocID, :DeptNbr, :SubDeptNbr, :ClassNbr, :ItemgroupNbr,:SubClassNbr, :ChoiceNbr,:MasterSKU, :ColorNbr, :SizeNbr,
						:DimNbr, :InTransit, :StrOnOrder, :ATTR_1_CODE, :ATTR_2_CODE, :ATTR_3_CODE, :ATTR_4_CODE, :ATTR_5_CODE, :ATTR_6_CODE, :ATTR_7_CODE, :ATTR_8_CODE, :ATTR_9_CODE, :ATTR_10_CODE, :ATTR_11_CODE, :ATTR_12_CODE)'
				USING r_aalapr.location_number, r_aalapr.department_number, r_aalapr.subdepartment_number, r_aalapr.class_number,r_aalapr.item_group_number, r_aalapr.subclass_number,
					 r_aalapr.choice_number, r_aalapr.master_sku, r_aalapr.color_code, r_aalapr.size_code, r_aalapr.dimension_code,
					 r_aalapr.in_transit_quantity, r_aalapr.str_on_order, r_aalapr.ATTR_1_CODE, r_aalapr.ATTR_2_CODE, r_aalapr.ATTR_3_CODE, r_aalapr.ATTR_4_CODE, r_aalapr.ATTR_5_CODE, r_aalapr.ATTR_6_CODE, r_aalapr.ATTR_7_CODE, r_aalapr.ATTR_8_CODE, r_aalapr.ATTR_9_CODE, r_aalapr.ATTR_10_CODE, r_aalapr.ATTR_11_CODE, r_aalapr.ATTR_12_CODE;
		END IF;

		-- All On-Hand will be put into the ON_HAND_CURR column.
		-- The roll will move the on-hand into 1-ago, etc.
		IF (v_weeksago = 0) THEN
			v_CurrentName	:= 'WTD_SALES';
		ELSE
			IF (v_weeksago < 10) THEN
				v_CurrentName	:= 'SLS_0' || TO_CHAR(v_weeksago) || 'AGO';
			ELSE
				v_CurrentName	:= 'SLS_' || TO_CHAR(v_weeksago) || 'AGO';
			END IF;
		END IF;

		IF (v_PrevWeek < 10) THEN
			v_PreviousName	:= 'SLS_0' || TO_CHAR(v_PrevWeek) || 'AGO';
		ELSE
			v_PreviousName	:= 'SLS_' || TO_CHAR(v_PrevWeek) || 'AGO';
		END IF;


        IF (v_weeksago = 0) THEN
            v_CurrentName1    := 'REG_SLS_WTD';
        ELSE
            IF (v_weeksago < 10) THEN
                v_CurrentName1    := 'REG_SLS_0' || TO_CHAR(v_weeksago) || 'AGO';
            ELSE
                v_CurrentName1    := 'REG_SLS_' || TO_CHAR(v_weeksago) || 'AGO';
            END IF;
        END IF;

        IF (v_PrevWeek < 10) THEN
            v_PreviousName1    := 'REG_SLS_0' || TO_CHAR(v_PrevWeek) || 'AGO';
        ELSE
            v_PreviousName1    := 'REG_SLS_' || TO_CHAR(v_PrevWeek) || 'AGO';
        END IF;

		-- UPDATE the STAGE_DIMENSION table
    v_arrUpdateStmt	:=
			'UPDATE /*+ index(stage_dimension stage_dimension_idx) */ stage_dimension ' || v_LF ||
			'  SET on_hand_curr	= :OnHand, ' || v_LF ||
			'		dnf_intransit	= :InTransit, ' || v_LF ||
			'       str_on_order    = :StrOnOrder, ' || v_LF ||
					v_CurrentName || '  = :CurrSales, ' || v_LF ||
					v_PreviousName || ' = :PrevSales, ' || v_LF ||
                    v_CurrentName1 || '  = :CurrSales1, ' || v_LF ||
                    v_PreviousName1 || ' = :PrevSales1, ' || v_LF ||
            '       ATTR_1_CODE     = :ATTR_1_CODE, ' ||v_LF ||
            '       ATTR_2_CODE     = :ATTR_2_CODE, ' ||v_LF ||
            '       ATTR_3_CODE     = :ATTR_3_CODE, ' ||v_LF ||
            '       ATTR_4_CODE     = :ATTR_4_CODE, ' ||v_LF ||
            '       ATTR_5_CODE     = :ATTR_5_CODE, ' ||v_LF ||
            '       ATTR_6_CODE     = :ATTR_6_CODE, ' ||v_LF ||
            '       ATTR_7_CODE     = :ATTR_7_CODE, ' ||v_LF ||
            '       ATTR_8_CODE     = :ATTR_8_CODE, ' ||v_LF ||
            '       ATTR_9_CODE     = :ATTR_9_CODE, ' ||v_LF ||
            '       ATTR_10_CODE     = :ATTR_10_CODE, ' ||v_LF ||
            '       ATTR_11_CODE     = :ATTR_11_CODE, ' ||v_LF ||
            '       ATTR_12_CODE     = :ATTR_12_CODE ' ||v_LF ||
			'  WHERE location_id = :LocID' || v_LF ||
			'   AND dept_nbr    = :DeptNbr' || v_LF ||
			'   AND subdept_nbr = :SubDeptNbr' || v_LF ||
			'   AND class_nbr   = :ClassNbr' || v_LF ||
            '   AND item_group_nbr   = :itemgroupNbr' || v_LF ||
			'   AND subclass_nbr= :SubClassNbr' || v_LF ||
            '   AND choice_nbr= :ChoiceNbr' || v_LF ||
			'   AND style_master_sku = :MasterSku' || v_LF ||
			'   AND color_nbr   = :ColorNbr' || v_LF ||
			v_arrSubClause;

		-- Update all of the quantities.
		IF r_aalapr.size_code IS NULL THEN
			-- Do the STAGE_DIMENSION table
      EXECUTE IMMEDIATE
				v_arrUpdateStmt
				USING	r_aalapr.on_hand_qty,		    r_aalapr.in_transit_quantity,   r_aalapr.str_on_order,
					    r_aalapr.sales_qty_curr,        r_aalapr.sales_qty_prev,	    r_aalapr.reg_sales_qty_curr,
                        r_aalapr.reg_sales_qty_prev,    r_aalapr.attr_1_code,           r_aalapr.attr_2_code,
                        r_aalapr.attr_3_code,           r_aalapr.attr_4_code,           r_aalapr.attr_5_code,
                        r_aalapr.attr_6_code,           r_aalapr.attr_7_code,           r_aalapr.attr_8_code,
                        r_aalapr.attr_9_code,           r_aalapr.attr_10_code,          r_aalapr.attr_11_code,
                        r_aalapr.attr_12_code,          r_aalapr.location_number,	    r_aalapr.department_number,
                        r_aalapr.subdepartment_number,  r_aalapr.class_number,	        r_aalapr.item_group_number,
                        r_aalapr.subclass_number,       r_aalapr.choice_number,         r_aalapr.master_sku,
                        r_aalapr.color_code;

 		ELSIF r_aalapr.dimension_code IS NULL THEN
			EXECUTE IMMEDIATE
				v_arrUpdateStmt
				USING	r_aalapr.on_hand_qty,            r_aalapr.in_transit_quantity,   r_aalapr.str_on_order,
                        r_aalapr.sales_qty_curr,         r_aalapr.sales_qty_prev,        r_aalapr.reg_sales_qty_curr,
                        r_aalapr.reg_sales_qty_prev,     r_aalapr.attr_1_code,           r_aalapr.attr_2_code,
                        r_aalapr.attr_3_code,            r_aalapr.attr_4_code,           r_aalapr.attr_5_code,
                        r_aalapr.attr_6_code,            r_aalapr.attr_7_code,           r_aalapr.attr_8_code,
                        r_aalapr.attr_9_code,            r_aalapr.attr_10_code,          r_aalapr.attr_11_code,
                        r_aalapr.attr_12_code,           r_aalapr.location_number,       r_aalapr.department_number,
                        r_aalapr.subdepartment_number,   r_aalapr.class_number,          r_aalapr.item_group_number,
                        r_aalapr.subclass_number,        r_aalapr.choice_number,         r_aalapr.master_sku,
                        r_aalapr.color_code,		     r_aalapr.size_code;

		ELSE	-- Have data at the dimension level.
			EXECUTE IMMEDIATE
				v_arrUpdateStmt
				USING	r_aalapr.on_hand_qty,            r_aalapr.in_transit_quantity,   r_aalapr.str_on_order,
                        r_aalapr.sales_qty_curr,         r_aalapr.sales_qty_prev,        r_aalapr.reg_sales_qty_curr,
                        r_aalapr.reg_sales_qty_prev,     r_aalapr.attr_1_code,           r_aalapr.attr_2_code,
                        r_aalapr.attr_3_code,            r_aalapr.attr_4_code,           r_aalapr.attr_5_code,
                        r_aalapr.attr_6_code,            r_aalapr.attr_7_code,           r_aalapr.attr_8_code,
                        r_aalapr.attr_9_code,            r_aalapr.attr_10_code,          r_aalapr.attr_11_code,
                        r_aalapr.attr_12_code,           r_aalapr.location_number,       r_aalapr.department_number,
                        r_aalapr.subdepartment_number,   r_aalapr.class_number,          r_aalapr.item_group_number,
                        r_aalapr.subclass_number,        r_aalapr.choice_number,         r_aalapr.master_sku,
                        r_aalapr.color_code,             r_aalapr.size_code,             r_aalapr.dimension_code;
		END IF;

		-- Line counter for records counting.
		record_no := record_no + 1;

		IF MOD (record_no, chunk) = 0 THEN -- for testing
			-- Inserts into log_table every "chunk" number of records.
			INSERT INTO log_table(record_nbr, location_id, dept_nbr, subdept_nbr, class_nbr,item_group_nbr,
								  subclass_nbr, choice_nbr, master_sku, color_nbr, size_nbr, dim_nbr, status)
				 VALUES (record_no, r_aalapr.location_number, r_aalapr.department_number, r_aalapr.subdepartment_number, r_aalapr.class_number,r_aalapr.item_group_number,
						 r_aalapr.subclass_number, r_aalapr.choice_number,r_aalapr.master_sku, r_aalapr.color_code, r_aalapr.size_code, r_aalapr.dimension_code, 'Record Processed');

			COMMIT;

			DBMS_OUTPUT.put_line(TO_CHAR(record_no) || ' records commited.');
		END IF;
	END LOOP;

  -- Now that STAGE_DIMENSION has changed, update STAGE_SUBCLASS
  AllocMMS.RebuildStageSubclass;
  AllocMMS.RebuildStageclass;

	-- Inserts into log_table with last good record.
	INSERT INTO	log_table(record_nbr, status)
		 VALUES	(record_no, 'Last Record Processed');

	COMMIT;
	DBMS_OUTPUT.put_line (TO_CHAR(record_no) || ' records commited.');
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		LogError (NULL, SQLERRM, SQLCODE, record_no);
		RAISE;    -- Send the error back so that we'll get a log in the middleware.
END proc_aalapr;


/* Following procedure proc_aalapw has been modified by Abhi Sharma (JDA Software):
   - Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes.
   - Added a logic to handle the REG_SLS for Current and History weeks as per the
     CR changes.
*/
PROCEDURE proc_aalapw(p_bCalledForRebuild	IN BOOLEAN) AS
	CURSOR cur_aalapw IS
		SELECT	location_number,	department_number,	subdepartment_number,
				class_number,item_group_number,		subclass_number,choice_number,	NVL(color_code, 0) color_cd,
				size_code,			dimension_code,		master_sku,
				year,				week,
				NVL (sales_quantity_prev, 0) sales_qty_prev,
				NVL (sales_quantity_curr, 0) sales_qty_curr,
				NVL (on_hand_quantity, 0) on_hand_qty,
				NVL (on_order_quantity, 0) str_on_order,
				in_transit_quantity,
                ATTR_1_CODE,
                ATTR_2_CODE,
                ATTR_3_CODE,
                ATTR_4_CODE,
                ATTR_5_CODE,
                ATTR_6_CODE,
                ATTR_7_CODE,
                ATTR_8_CODE,
                ATTR_9_CODE,
                ATTR_10_CODE,
                ATTR_11_CODE,
                ATTR_12_CODE,
                NVL (REG_SALES_QTY_CURR, 0) reg_sales_qty_curr,
                NVL (REG_SALES_QTY_PREV, 0) reg_sales_qty_prev
		  FROM	aalapw;

	chunk  CONSTANT PLS_INTEGER			:= 100000;
	key_count		PLS_INTEGER;
	item_level		PLS_INTEGER;
	cur_week_order	calendar.week_order%TYPE;
	v_weeksago		calendar.week_order%TYPE;
	v_PrevWeek		calendar.week_order%TYPE;
	dest_cursor		INTEGER;
	ignore			INTEGER;
	record_no		NUMBER(10)			:= 0;
	wclause			VARCHAR2(4000);
	wclause2		VARCHAR2(4000);
	teststring		VARCHAR2(4000);
	colname_oh		VARCHAR2(20)		:= 'ON_HAND_CURR';
	colname_it		VARCHAR2(20)		:= 'DNF_INTRANSIT';
    colname_soo     VARCHAR2(20)    := 'STR_ON_ORDER';
	colname_att1    VARCHAR2(20)    := 'ATTR_1_CODE';
    colname_att2    VARCHAR2(20)    := 'ATTR_2_CODE';
    colname_att3    VARCHAR2(20)    := 'ATTR_3_CODE';
    colname_att4    VARCHAR2(20)    := 'ATTR_4_CODE';
    colname_att5    VARCHAR2(20)    := 'ATTR_5_CODE';
    colname_att6    VARCHAR2(20)    := 'ATTR_6_CODE';
    colname_att7    VARCHAR2(20)    := 'ATTR_7_CODE';
    colname_att8    VARCHAR2(20)    := 'ATTR_8_CODE';
    colname_att9    VARCHAR2(20)    := 'ATTR_9_CODE';
    colname_att10   VARCHAR2(20)    := 'ATTR_10_CODE';
    colname_att11   VARCHAR2(20)    := 'ATTR_11_CODE';
    colname_att12   VARCHAR2(20)    := 'ATTR_12_CODE';
    v_CurrentName	VARCHAR2(20);
	v_PreviousName	VARCHAR2(20);
    v_CurrentName1  VARCHAR2(20);
    v_PreviousName1        VARCHAR2(20);
	v_arrStatusError	log_table.status%TYPE	:= 'Weekly History not updated.';
	v_arrProcName		VARCHAR2(35)			:= 'Proc_aalapw';
	v_bTableTruncated	BOOLEAN;
BEGIN
	COMMIT;

	-- To speed up removing records from log_table:
	v_bTableTruncated	:= AllocMMS.TruncateTable('log_table');

	IF NOT v_bTableTruncated THEN
		LogError(v_arrStatusError, v_arrProcname || ': Not able to truncate table ''log_table''.');
		RETURN;
	END IF;

	wclause := ' location_id = :location_number'
			|| ' and dept_nbr = :department_number'
			|| ' and subdept_nbr = :subdepartment_number'
			|| ' and class_nbr = :class_number'
            || ' and item_group_nbr = :item_group_number'
			|| ' and subclass_nbr = :subclass_number'
            || ' and choice_nbr = :choice_number'
			|| ' and style_master_sku = :master_sku'
			|| ' and color_nbr = :color_code';

	SELECT	week_order
	  INTO	cur_week_order
	  FROM	calendar
	 WHERE	current_week	= 'Y';



	FOR aalapw_rec IN cur_aalapw LOOP
		SELECT	(cur_week_order - week_order)
		  INTO	v_weeksago
		  FROM	calendar
		 WHERE	year	= aalapw_rec.year
		   AND	week	= aalapw_rec.week;

		v_PrevWeek   := v_weeksago + 1;

		IF aalapw_rec.size_code IS NULL THEN
			wclause2	:= ' and size_nbr is null and dim_nbr is null';
			item_level	:= 1;

			EXECUTE IMMEDIATE 'SELECT	/*+ index(stage_dimension stage_dimension_idx) */ COUNT(dept_nbr) ' ||
			  'FROM	stage_dimension ' ||
			 'WHERE	location_id	= :location_number ' ||
			   'AND	dept_nbr	= :department_number ' ||
			   'AND	subdept_nbr	= :subdepartment_number ' ||
			   'AND	class_nbr	= :class_number ' ||
               'AND  item_group_nbr    = :item_group_number ' ||
			   'AND	subclass_nbr= :subclass_number ' ||
                'AND choice_nbr= :choice_number ' ||
			   'AND	style_master_sku= :master_sku ' ||
			   'AND	color_nbr	= :color_cd ' ||
			   'AND	size_nbr IS NULL ' ||
			   'AND	dim_nbr IS NULL'
		INTO key_count
        USING aalapw_rec.location_number, aalapw_rec.department_number,  aalapw_rec.subdepartment_number,
              aalapw_rec.class_number,    aalapw_rec.subclass_number,    aalapw_rec.master_sku,
              aalapw_rec.color_cd;

		ELSIF aalapw_rec.dimension_code IS NULL THEN
			wclause2	:= ' and size_nbr = :size_code and dim_nbr is null';
			item_level	:= 2;

			EXECUTE IMMEDIATE 'SELECT	/*+ index(stage_dimension stage_dimension_idx) */ COUNT(*) ' ||
			  'FROM stage_dimension ' ||
			 'WHERE location_id	= :location_number ' ||
			   'AND dept_nbr		= :department_number ' ||
			   'AND subdept_nbr	= :subdepartment_number ' ||
			   'AND class_nbr	= :class_number ' ||
                'AND item_group_nbr    = :item_group_number ' ||
			   'AND subclass_nbr	= :subclass_number ' ||
               'AND choice_nbr    = :choice_number ' ||
			   'AND style_master_sku= :master_sku ' ||
			   'AND color_nbr	= :color_cd ' ||
			   'AND size_nbr		= :size_code ' ||
			   'AND dim_nbr IS NULL'
		INTO key_count
        USING aalapw_rec.location_number,    aalapw_rec.department_number,  aalapw_rec.subdepartment_number,
              aalapw_rec.class_number,       aalapw_rec.item_group_number,  aalapw_rec.subclass_number,
              aalapw_rec.choice_number,      aalapw_rec.master_sku,         aalapw_rec.color_cd,
              aalapw_rec.size_code;
		ELSE
			wclause2	:= ' and size_nbr = :size_code and dim_nbr = :dimension_code';
			item_level	:= 3;

			EXECUTE IMMEDIATE 'SELECT	/*+ index(stage_dimension stage_dimension_idx) */ COUNT(*) ' ||
			  'FROM	stage_dimension ' ||
			 'WHERE	location_id	= :location_number ' ||
			   'AND	dept_nbr	= :department_number ' ||
			   'AND	subdept_nbr	= :subdepartment_number ' ||
			   'AND	class_nbr	= :class_number ' ||
               'AND item_group_nbr    = :item_group_number ' ||
			   'AND	subclass_nbr= :subclass_number ' ||
                'AND choice_nbr    = :choice_number ' ||
			   'AND	style_master_sku= :master_sku ' ||
			   'AND	color_nbr	= :color_cd ' ||
			   'AND	size_nbr	= :size_code ' ||
			   'AND	dim_nbr		= :dimension_code'
			  INTO	key_count
        USING aalapw_rec.location_number,   aalapw_rec.department_number,   aalapw_rec.subdepartment_number,
              aalapw_rec.class_number,      aalapw_rec.item_group_number,   aalapw_rec.subclass_number,
              aalapw_rec.choice_number,     aalapw_rec.master_sku,          aalapw_rec.color_cd,
              aalapw_rec.size_code,         aalapw_rec.dimension_code;
		END IF;

		IF key_count < 1 THEN
       -- Update the STAGE_DIMENSION table
    	EXECUTE IMMEDIATE 'INSERT INTO stage_dimension( ' ||
					'location_id, ' ||
					'dept_nbr, ' ||
					'subdept_nbr, ' ||
					'class_nbr, ' ||
                    'item_group_nbr, ' ||
					'subclass_nbr, ' ||
                    'choice_nbr, ' ||
					'str_on_order, ' ||
					'style_master_sku, ' ||
					'color_nbr, ' ||
					'size_nbr, ' ||
					'dim_nbr, ' ||
                    'dnf_intransit, ' ||
                    'ATTR_1_CODE, ' ||
                    'ATTR_2_CODE, ' ||
                    'ATTR_3_CODE, ' ||
                    'ATTR_4_CODE, ' ||
                    'ATTR_5_CODE, ' ||
                    'ATTR_6_CODE, ' ||
                    'ATTR_7_CODE, ' ||
                    'ATTR_8_CODE, ' ||
                    'ATTR_9_CODE, ' ||
                    'ATTR_10_CODE, ' ||
                    'ATTR_11_CODE, ' ||
                    'ATTR_12_CODE)' ||
				 'VALUES ( :p1, :p2, :p3, :p5, :p6, :p7, :p8, :p9, :p10, :p11, :p12, :p13, :p14, :p15, :p16, :p17, :p18, :p19, :p20, :p21, :p22, :p23, :p24, :p25, :p26)'
          USING
  					aalapw_rec.location_number,
  					aalapw_rec.department_number,
  					aalapw_rec.subdepartment_number,
  					aalapw_rec.class_number,
                    aalapw_rec.item_group_number,
  					aalapw_rec.subclass_number,
                    aalapw_rec.choice_number,
  					aalapw_rec.str_on_order,
  					aalapw_rec.master_sku,
  					aalapw_rec.color_cd,
  					aalapw_rec.size_code,
  					aalapw_rec.dimension_code,
                    aalapw_rec.in_transit_quantity,
                    aalapw_rec.attr_1_code,
                    aalapw_rec.attr_2_code,
                    aalapw_rec.attr_3_code,
                    aalapw_rec.attr_4_code,
                    aalapw_rec.attr_5_code,
                    aalapw_rec.attr_6_code,
                    aalapw_rec.attr_7_code,
                    aalapw_rec.attr_8_code,
                    aalapw_rec.attr_9_code,
                    aalapw_rec.attr_10_code,
                    aalapw_rec.attr_11_code,
                    aalapw_rec.attr_12_code;

    END IF;

	-- All On-Hand will be put into the ON_HAND_CURR column.
	-- The roll will move the on-hand into 1-ago, etc.
	IF (v_weeksago = 0) THEN
		v_CurrentName	:= 'WTD_SALES';
	ELSE
		IF (v_weeksago < 10) THEN
			v_CurrentName	:= 'SLS_0' || TO_CHAR(v_weeksago) || 'AGO';
		ELSE
			v_CurrentName	:= 'SLS_' || TO_CHAR(v_weeksago) || 'AGO';
		END IF;
	END IF;

	IF (v_PrevWeek < 10) THEN
		v_PreviousName	:= 'SLS_0' || TO_CHAR(v_PrevWeek) || 'AGO';
	ELSE
		v_PreviousName	:= 'SLS_' || TO_CHAR(v_PrevWeek) || 'AGO';
	END IF;


    IF (v_weeksago = 0) THEN
        v_CurrentName1    := 'REG_SLS_WTD';
    ELSE
        IF (v_weeksago < 10) THEN
            v_CurrentName1    := 'REG_SLS_0' || TO_CHAR(v_weeksago) || 'AGO';
        ELSE
            v_CurrentName1    := 'REG_SLS_' || TO_CHAR(v_weeksago) || 'AGO';
        END IF;
    END IF;

    IF (v_PrevWeek < 10) THEN
        v_PreviousName1    := 'REG_SLS_0' || TO_CHAR(v_PrevWeek) || 'AGO';
    ELSE
        v_PreviousName1    := 'REG_SLS_' || TO_CHAR(v_PrevWeek) || 'AGO';
    END IF;


    teststring := 'update /*+ index(stage_dimension stage_dimension_idx) */ stage_dimension  set '
					|| colname_oh || ' = :on_hand_quantity, '
					|| v_CurrentName || ' = :sales_quantity_curr, '
					|| v_PreviousName || ' = :sales_quantity_prev, '
                    || v_CurrentName1 || ' = :reg_sales_quantity_curr1, '
                    || v_PreviousName1 || ' = :reg_sales_quantity_prev1, '
                    || colname_soo || ' = :str_on_order, '
					|| colname_it || ' = :in_transit_quantity, '
                    || colname_att1 ||' = :attr_1_code, '
                    || colname_att2 ||' = :attr_2_code, '
                    || colname_att3 ||' = :attr_3_code, '
                    || colname_att4 ||' = :attr_4_code, '
                    || colname_att5 ||' = :attr_5_code, '
                    || colname_att6 ||' = :attr_6_code, '
                    || colname_att7 ||' = :attr_7_code, '
                    || colname_att8 ||' = :attr_8_code, '
                    || colname_att9 ||' = :attr_9_code, '
                    || colname_att10 ||' = :attr_10_code, '
                    || colname_att11 ||' = :attr_11_code, '
                    || colname_att12 ||' = :attr_12_code '
                    || '  where ' || wclause || wclause2;

		dest_cursor		:= DBMS_SQL.open_cursor;
		DBMS_SQL.parse (dest_cursor, teststring, DBMS_SQL.v7);
		DBMS_SQL.bind_variable (dest_cursor,	'on_hand_quantity',		       aalapw_rec.on_hand_qty);
		DBMS_SQL.bind_variable (dest_cursor,	'sales_quantity_curr',	       aalapw_rec.sales_qty_curr);
		DBMS_SQL.bind_variable (dest_cursor,	'sales_quantity_prev',	       aalapw_rec.sales_qty_prev);
        DBMS_SQL.bind_variable (dest_cursor,    'reg_sales_quantity_curr1',    aalapw_rec.reg_sales_qty_curr);
        DBMS_SQL.bind_variable (dest_cursor,    'reg_sales_quantity_prev1',    aalapw_rec.reg_sales_qty_prev);
		DBMS_SQL.bind_variable (dest_cursor,	'location_number',		       aalapw_rec.location_number);
		DBMS_SQL.bind_variable (dest_cursor,	'department_number',	       aalapw_rec.department_number);
		DBMS_SQL.bind_variable (dest_cursor,	'subdepartment_number',	       aalapw_rec.subdepartment_number);
		DBMS_SQL.bind_variable (dest_cursor,	'class_number',			       aalapw_rec.class_number);
        DBMS_SQL.bind_variable (dest_cursor,    'item_group_number',           aalapw_rec.item_group_number);
		DBMS_SQL.bind_variable (dest_cursor,	'subclass_number',		       aalapw_rec.subclass_number);
        DBMS_SQL.bind_variable (dest_cursor,    'choice_number',               aalapw_rec.choice_number);
		DBMS_SQL.bind_variable (dest_cursor,    'str_on_order',                aalapw_rec.str_on_order);
		DBMS_SQL.bind_variable (dest_cursor,	'master_sku',			       aalapw_rec.master_sku);
		DBMS_SQL.bind_variable (dest_cursor,	'color_code',			       aalapw_rec.color_cd);
        DBMS_SQL.bind_variable (dest_cursor,	'in_transit_quantity',	       aalapw_rec.in_transit_quantity);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_1_code',                 aalapw_rec.attr_1_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_2_code',                 aalapw_rec.attr_2_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_3_code',                 aalapw_rec.attr_3_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_4_code',                 aalapw_rec.attr_4_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_5_code',                 aalapw_rec.attr_5_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_6_code',                 aalapw_rec.attr_6_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_7_code',                 aalapw_rec.attr_7_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_8_code',                 aalapw_rec.attr_8_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_9_code',                 aalapw_rec.attr_9_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_10_code',                aalapw_rec.attr_10_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_11_code',                aalapw_rec.attr_11_code);
        DBMS_SQL.bind_variable (dest_cursor,    'attr_12_code',                aalapw_rec.attr_12_code);

		IF item_level > 1 THEN
			DBMS_SQL.bind_variable (dest_cursor,	'size_code',		aalapw_rec.size_code);

			IF item_level > 2 THEN
				DBMS_SQL.bind_variable (dest_cursor,'dimension_code',	aalapw_rec.dimension_code);
			END IF;
		END IF;

		ignore		:= DBMS_SQL.EXECUTE(dest_cursor);

		DBMS_SQL.CLOSE_CURSOR(dest_cursor);

    -- Line counter for record counting
		record_no	:= record_no + 1;

		IF MOD (record_no, chunk) = 0 THEN  -- for testing
			-- Inserts into log_table every "chunk" number of records.
			INSERT INTO log_table(
					record_nbr,
					location_id,
					dept_nbr,
					subdept_nbr,
					class_nbr,
                    item_group_nbr,
					subclass_nbr,
                    choice_nbr,
					master_sku,
					color_nbr,
					size_nbr,
					dim_nbr,
					status)
				 VALUES (
					record_no,
					aalapw_rec.location_number,
					aalapw_rec.department_number,
					aalapw_rec.subdepartment_number,
					aalapw_rec.class_number,
                    aalapw_rec.item_group_number,
					aalapw_rec.subclass_number,
                    aalapw_rec.choice_number,
					aalapw_rec.master_sku,
					aalapw_rec.color_cd,
					aalapw_rec.size_code,
					aalapw_rec.dimension_code,
					'Record Processed');

			COMMIT;

			DBMS_OUTPUT.put_line (TO_CHAR(record_no) || ' records commited.');
		END IF;
	END LOOP;	-- cursor

  -- Now that STAGE_DIMENSION has changed, update STAGE_SUBCLASS
  AllocMMS.RebuildStageSubclass;
  AllocMMS.RebuildStageclass;

	-- Inserts into log_table the last good record.
	INSERT INTO	log_table(record_nbr, status)
		 VALUES	(record_no, 'Last Record Processed');

	COMMIT;
	DBMS_OUTPUT.put_line (TO_CHAR(record_no) || '  records commited. ');
EXCEPTION
	WHEN OTHERS THEN
		IF DBMS_SQL.IS_OPEN(dest_cursor) THEN
			DBMS_SQL.CLOSE_CURSOR(dest_cursor);
		END IF;

		ROLLBACK;

		LogError (NULL, SQLERRM, SQLCODE, record_no);
	    RAISE;    -- Send the error back so that we'll get a log in the middleware.
END proc_aalapw;

PROCEDURE UpdateWLShapeTables(
	p_wlkey				IN worklist.wl_key%TYPE,
	p_aalwrk			IN aalwrk%ROWTYPE,
  p_PackID IN worklist.pack_id%TYPE,
  p_NbrPacks IN worklist.nbr_packs%TYPE,
  p_OrderPacks IN worklist.on_order_packs%TYPE,
	p_bCalledForRebuild		IN BOOLEAN	DEFAULT FALSE )
IS
PRAGMA AUTONOMOUS_TRANSACTION;
	v_arrStatusError	log_table.status%TYPE	:= 'Shape Processing Error.';
	v_arrProcName		VARCHAR2(35)		:= 'UpdateWLShapeTables';
	v_ShapeTypeNbr		NUMBER;
BEGIN
	v_ShapeTypeNbr		:= get_shape_type(p_aalwrk.Dimension_Number, p_aalwrk.Size_number, p_aalwrk.Color_number);

	IF v_ShapeTypeNbr = const_style_shape THEN -- Style level
    BEGIN
			UPDATE pack_style
			  SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				style_master_sku = p_aalwrk.style_master_sku,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3,
        pack_id = p_PackID
			WHERE wl_key = p_wlkey;
--			  AND PACK_ID = p_PackID;
      IF SQL%rowcount = 0 THEN
        BEGIN
  		    INSERT
    		  INTO pack_style
    		       (wl_key,
    			line_sequence,
    			style_master_sku,
    			pack_id,
    			nbr_packs,
    			qty_per_pack,
    			avail_qty,
    			on_order_balance,
    			retail_price,
    			po_line_comments)
    		VALUES (p_wlkey,
                NVL(p_aalwrk.line_sequence, 0),
    			p_aalwrk.style_master_sku,
    			p_PackID,
    			p_NbrPacks,
    			p_aalwrk.quantity_per_pack,
    			p_aalwrk.quantity_per_pack * p_NbrPacks,
    			p_aalwrk.quantity_per_pack * p_OrderPacks,
    			p_aalwrk.retail_price,
    			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
  		  END;
      END IF;
    END;
  ELSIF v_ShapeTypeNbr = const_color_shape THEN -- Color level
    BEGIN
  			UPDATE pack_color
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
               	style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number;
      IF SQL%rowcount = 0 THEN
        BEGIN
    	    INSERT
    		  INTO pack_color
    		       (wl_key,
    			line_sequence,
    			style_master_sku,
    			color_nbr,
    			color_name,
    			pack_id,
    			nbr_packs,
    			qty_per_pack,
    			avail_qty,
    			on_order_balance,
    			retail_price,
    			po_line_comments)
    		VALUES (p_wlkey,
    			NVL(p_aalwrk.line_sequence, 0),
                p_aalwrk.style_master_sku,
    			p_aalwrk.color_number,
    			p_aalwrk.color_name,
    			p_PackID,
    			p_NbrPacks,
    			p_aalwrk.quantity_per_pack,
    			p_aalwrk.quantity_per_pack * p_NbrPacks,
    			p_aalwrk.quantity_per_pack * p_OrderPacks,
    			p_aalwrk.retail_price,
    			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
  	    END;
      END IF;
    END;
	ELSIF v_ShapeTypeNbr = const_size_shape THEN -- Size level
	  BEGIN
			UPDATE pack_size
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				size_name = p_aalwrk.size_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number
			  AND size_nbr = p_aalwrk.size_number;
    IF SQL%rowcount = 0 THEN
      BEGIN
        INSERT
  		  INTO pack_size
  		       (wl_key,
  			line_sequence,
  			style_master_sku,
  			color_nbr,
  			color_name,
  			size_nbr,
  			size_name,
  			pack_id,
  			nbr_packs,
  			qty_per_pack,
  			avail_qty,
  			on_order_balance,
  			retail_price,
  			po_line_comments)
  		VALUES (p_wlkey,
  			NVL(p_aalwrk.line_sequence, 0),
  			p_aalwrk.style_master_sku,
  			p_aalwrk.color_number,
  			p_aalwrk.color_name,
  			p_aalwrk.size_number,
  			p_aalwrk.size_name,
  			p_PackID,
  			p_NbrPacks,
  			p_aalwrk.quantity_per_pack,
  			p_aalwrk.quantity_per_pack * p_NbrPacks,
  			p_aalwrk.quantity_per_pack * p_OrderPacks,
  			p_aalwrk.retail_price,
  			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
     END;
   END IF;
   END;
	ELSIF v_ShapeTypeNbr = const_dimension_shape THEN -- Dimension level
    BEGIN
			UPDATE pack_dimension
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				size_name = p_aalwrk.size_name,
				dim_name = p_aalwrk.dimension_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number
			  AND size_nbr = p_aalwrk.size_number
			  AND dim_nbr = p_aalwrk.dimension_number;

      IF SQL%rowcount = 0 THEN
        BEGIN
          INSERT
    		  INTO pack_dimension
    		       (wl_key,
    			line_sequence,
    			style_master_sku,
    			color_nbr,
    			color_name,
    			size_nbr,
    			size_name,
    			dim_nbr,
    			dim_name,
    			pack_id,
    			nbr_packs,
    			qty_per_pack,
    			avail_qty,
    			on_order_balance,
    			retail_price,
    			po_line_comments)
          VALUES (p_wlkey,
    			NVL(p_aalwrk.line_sequence, 0),
    			p_aalwrk.style_master_sku,
    			p_aalwrk.color_number,
    			p_aalwrk.color_name,
    			p_aalwrk.size_number,
    			p_aalwrk.size_name,
    			p_aalwrk.dimension_number,
    			p_aalwrk.dimension_name,
    			p_PackID,
    			p_NbrPacks,
    			p_aalwrk.quantity_per_pack,
    			p_aalwrk.quantity_per_pack * p_NbrPacks,
    			p_aalwrk.quantity_per_pack * p_OrderPacks,
    			p_aalwrk.retail_price,
    			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
        END;
      END IF;
    END;
	END IF;
	-- Check the status on the worklist for the record we are updating
	-- if it is approved or unapproved, then compare the old-avail_qty from worklist
	-- sum up with the new avail qty from the detail table and compare the old and new
	-- and if it is different, then mark them discrepent.
	COMMIT;
	sum_avail(p_wlkey);
	sum_oob(p_wlkey);

	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		LogError(v_arrStatusError, v_arrProcName || ': General Error [' || SQLERRM || '].');
END UpdateWLShapeTables;


--
-- This handles a worklist / shape deletion
-- it no longer handles wildcard deletions, but the name stuck
--
-- PO, BO, receiver nbr, vendor pack, and SKU are always specified, but the low level details
-- will depend on the shape
--
-- There are four cases:
-- 1) Color, Size, and Dimension can be NULL
-- 2) Size and Dimension can be NULL
-- 3) Dimension can be NULL
-- 4) Color, Size, and Dimension can be non-NULL

-- This procedure could also be used to delete a line from a shape detail and not an entire WL line.
PROCEDURE proc_aalwrk_do_wildcard_del (
	p_PONbr			aalwrk.po_dst_number%TYPE,
	p_BONbr			aalwrk.bo_number%TYPE,
  p_RcvNumber  IN aalwrkq.receiver_number%TYPE,
  p_VendorPackID IN aalwrkq.vendor_pack%TYPE,
	p_ColorNbr		aalwrk.color_number%TYPE,
	p_SizeNbr		aalwrk.size_number%TYPE,
	p_DimNbr		aalwrk.dimension_number%TYPE,
	p_SkuNbr		aalwrk.style_master_sku%TYPE)
AS
	-- This cursor is used to form list of candidate worklist keys for deletion.
  -- In theory, it should never find more than one WL line that matches all key fields,
  -- but it might find none.  In the future, it may be used again for wildcard deletion.
  CURSOR c_CandidateKeys(
			v_PONbr		aalwrk.po_dst_number%TYPE,
			v_BONbr		aalwrk.bo_number%TYPE,
      v_RcvNumber aalwrk.receiver_number%TYPE,
      v_VendorPackID aalwrk.vendor_pack%TYPE,
			v_SkuNbr	aalwrk.style_master_sku%TYPE,
			v_ColorNbr	aalwrk.color_number%TYPE) IS
		SELECT	wl_key, status_code
		  FROM	worklist
		 WHERE	po_nbr		= NVL (v_PONbr, 'NOPONBR')
		   AND	bo_nbr		= NVL (v_BONbr, 0)
       AND  receiving_id = NVL (v_RcvNumber, 0)
       AND  NVL (vendor_pack_id, 'NOPACK') = NVL (v_VendorPackID, 'NOPACK')
		   AND	style_master_sku= NVL (v_SkuNbr, 0)
		   AND	( ((vendor_pack_id is null) AND (NVL (color_nbr,  'NOCOLOR')	= NVL (v_ColorNbr, 'NOCOLOR'))) OR (vendor_pack_id is not null) )
		   AND	status_code <> const_released;


	t_STSelectRemainderStmt	t_FieldNames;
	t_STSelectStmt	t_FieldNames;
	t_STDeleteStmt  t_FieldNames;

	v_arrSTablePack	VARCHAR2(30);

	v_arrWhereStmt	VARCHAR2(100);

	v_Level			NUMBER;
	v_STypePack		NUMBER;
	v_NumRecords	PLS_INTEGER;

BEGIN
	-- We try to extrapolate the shape type based on whether or not
	-- the color, size, and dimension are specified.
	IF (p_ColorNbr IS NULL OR p_ColorNbr = '0') AND p_SizeNbr IS NULL AND p_DimNbr IS NULL THEN
		v_Level			:= 0;
    v_arrWhereStmt	:= '';
	ELSIF p_SizeNbr IS NULL AND p_DimNbr IS NULL THEN
		v_Level			:= 1;
		v_arrWhereStmt	:= '   AND  color_nbr   = :ColorNbr';
	ELSIF p_DimNbr IS NULL THEN
		v_Level			:= 2;
		v_arrWhereStmt	:= '   AND  color_nbr   = :ColorNbr' || v_LF ||
				   '   AND  size_nbr	= :SizeNbr';
	ELSE
		v_Level			:= 3;
		v_arrWhereStmt	:= '   AND  color_nbr   = :ColorNbr' || v_LF ||
				   '   AND  size_nbr	= :SizeNbr' || v_LF ||
				   '   AND  dim_nbr     = :DimNbr';
	END IF;

	v_STypePack	:= g_stPack(v_Level);
	v_arrSTablePack	:= g_ListShapeTable(v_STypePack);

	t_STSelectRemainderStmt(1)	:= 'SELECT  COUNT(wl_key)' || v_LF ||
						   '  FROM  ' || v_arrSTablePack || v_LF ||
						   ' WHERE  wl_key  = :WLKey ' ;
	t_STSelectStmt(1)	:= 'SELECT  COUNT(wl_key)' || v_LF ||
						   '  FROM  ' || v_arrSTablePack || v_LF ||
						   ' WHERE  wl_key  = :WLKey' || v_LF ||
						   v_arrWhereStmt;

	t_STDeleteStmt(1)	:= 'DELETE' || v_LF ||
						   '  FROM ' || v_arrSTablePack || v_LF ||
						   ' WHERE wl_key = :WLKey' || v_LF ||
						   v_arrWhereStmt;

  -- There should only be one match, since we're using key fields, but selecting any matches
  -- into a cursor also handles cases where there's nothing to delete, and allows for future modification
  -- to allow multiple deletes

	FOR r_CandidateKeys IN c_CandidateKeys(p_PONbr, p_BONbr, p_RcvNumber, p_VendorPackID, p_SkuNbr, p_ColorNbr) LOOP

    -- Can't do anything, WL line is in progress. Queue the entry and continue.
    IF WorklistLineIsInProgress(r_CandidateKeys.wl_key) THEN
  			QueueDeleteToAALWRKQ(p_PONbr, p_BONbr, p_RcvNumber, p_VendorPackID, p_SkuNbr, p_ColorNbr, p_SizeNbr, p_DimNbr);

    ELSE -- not in progress, so process the delete
        IF v_Level = 0 THEN		-- at style level
  				EXECUTE IMMEDIATE
  					t_STSelectStmt(1)
  					INTO  v_NumRecords
  					USING r_CandidateKeys.wl_key;
  		  ELSIF v_Level = 1 THEN		-- At color level.
  				EXECUTE IMMEDIATE
  					t_STSelectStmt(1)
  					INTO  v_NumRecords
  					USING r_CandidateKeys.wl_key, p_ColorNbr;
  			ELSIF v_Level = 2 THEN	-- At size level.
  				EXECUTE IMMEDIATE
  					t_STSelectStmt(1)
  					INTO  v_NumRecords
  					USING r_CandidateKeys.wl_key, p_ColorNbr, p_SizeNbr;
  			ELSIF v_Level = 3 THEN	-- At dimension level.
  				EXECUTE IMMEDIATE
  					t_STSelectStmt(1)
  					INTO  v_NumRecords
  					USING r_CandidateKeys.wl_key, p_ColorNbr, p_SizeNbr, p_DimNbr;
  			END IF;

  			-- Approved/unapproved lines must be put into discrepancy if a shape detail line is deleted.
        IF v_NumRecords > 0 THEN
  			  IF r_CandidateKeys.status_code IN (const_approved, const_unapproved) THEN
  					PutWorklistLineIntoDiscrepancy(r_CandidateKeys.wl_key);
  					COMMIT;
  				END IF;

  				-- Delete the entry from the shape table.
  				IF v_Level = 0 THEN		-- At style level.
  					EXECUTE IMMEDIATE
  						t_STDeleteStmt(1)
  						USING r_CandidateKeys.wl_key;
  				ELSIF v_Level = 1 THEN		-- At color level.
  					EXECUTE IMMEDIATE
  						t_STDeleteStmt(1)
  						USING r_CandidateKeys.wl_key, p_ColorNbr;
  				ELSIF v_Level = 2 THEN	-- At size level.
  					EXECUTE IMMEDIATE
  						t_STDeleteStmt(1)
  						USING r_CandidateKeys.wl_key, p_ColorNbr, p_SizeNbr;
  				ELSIF v_Level = 3 THEN	-- At dimension level.
  					EXECUTE IMMEDIATE
  						t_STDeleteStmt(1)
  						USING r_CandidateKeys.wl_key, p_ColorNbr, p_SizeNbr, p_DimNbr;
  				END IF;

          COMMIT;
          sum_avail(r_CandidateKeys.wl_key);
          sum_oob(r_CandidateKeys.wl_key);
          COMMIT;

  				-- We have finished processing the wl_key, so now we need to check wether or not
  				-- we need to remove the wl_key entry from the worklist. We do this if there are no longer
  				-- any entries for the wl_key in it's shape table. Note, that if we get here, then
  				-- we know what the associated shape table is, and we know the level (v_level) from above.

  				-- All levels should be treated the same, since the presence of any WL key
  				-- in the shape table means that the WL key shouldn't be deleted from the WL

          IF (v_Level = 0 OR v_Level = 1 OR v_Level = 2 OR v_Level = 3) THEN -- all levels with shape tables
  			  	EXECUTE IMMEDIATE
  				  		t_STSelectRemainderStmt(1)
  					  	INTO  v_NumRecords
    						USING r_CandidateKeys.wl_key;
          END IF;


  				-- We have no entries for the wl_key left in the shape table, so queue
  				-- the key for deletion from the worklist. Note that this, as a by-product,
  				-- will also resissue the delete from the shape table, so only put the wl_key
  				-- value in here if you are sure of the delete.
          IF v_NumRecords = 0 THEN
  					INSERT INTO wl_del(wl_key, po_nbr, bo_nbr, receiving_id, vendor_pack_id, style_master_sku, color_nbr, shape_type)
  						 VALUES (r_CandidateKeys.wl_key, p_PONbr, p_BONbr, p_RcvNumber, p_VendorPackID, p_SkuNbr, p_ColorNbr, (4 - v_Level) /* corresponds to shape type -- was previously NULL, but not sure why JFC*/);

          END IF; -- do more detail records remain?
        END IF; -- were records found to delete?
    END IF; -- is line in progress
  END LOOP; -- of potential deletes
END proc_aalwrk_do_wildcard_del;



/* This routine is called by proc_aalwrk to handle the deletion of a worklist
 * record.  The actual deletion isn't performed, but entries are made in a
 * table of immediate deletions.  If the worklist line is in a state where
 * the deletion has to be deferred, then the deletion is queued in another
 * table that isn't immediately processed.
 */
PROCEDURE proc_aalwrk_handle_del(
	p_WLKey			worklist.wl_key%TYPE,
	p_PONbr			aalwrk.po_dst_number%TYPE,
	p_BONbr			aalwrk.bo_number%TYPE,
  p_RcvNumber  IN aalwrkq.receiver_number%TYPE,
  p_VendorPackID IN aalwrkq.vendor_pack%TYPE,
	p_SkuNbr		aalwrk.style_master_sku%TYPE,
	p_ColorNbr		aalwrk.color_number%TYPE,
	p_SizeNbr		aalwrk.size_number%TYPE,
	p_DimensionNbr		aalwrk.dimension_number%TYPE)
AS
	v_StatusCode	worklist.status_code%TYPE;
	v_ShapeType     NUMBER;
BEGIN
	v_StatusCode	:= func_wl_status_code(p_WLKey);

	IF v_StatusCode IN (const_available_to_allocate,	const_descrepancy,
						const_approved,					const_unapproved)
	THEN
		v_ShapeType := get_shape_type(p_DimensionNbr, p_SizeNbr, p_ColorNbr);

    INSERT INTO wl_del(wl_key, po_nbr, bo_nbr, receiving_id, vendor_pack_id, style_master_sku, color_nbr, shape_type)
			 VALUES (p_WLKey, p_PONbr, p_BONbr, p_RcvNumber, p_VendorPackID,p_SkuNbr, p_ColorNbr, v_ShapeType);
	END IF;

	IF v_StatusCode = const_in_progress THEN
		QueueDeleteToAALWRKQ(p_PONbr, p_BONbr, p_RcvNumber, p_VendorPackID, p_SkuNbr, p_ColorNbr, p_SizeNbr, p_DimensionNbr);
	END IF;
END proc_aalwrk_handle_del;


/* Following procedure proc_aalwrk has been modified by Abhi Sharma (JDA Software):
   Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
   based Data Collect as per the CR changes
*/
PROCEDURE proc_aalwrk(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
	CURSOR cur_addupd IS
		SELECT	*
		  FROM	aalwrk
		 WHERE	operation_code IN ('1', '2');

	CURSOR cur_del IS
		SELECT	*
		  FROM	aalwrk
		 WHERE	operation_code = '3';

  -- This is a list of queued records that might cause new wl keys to be added,
  -- assuming that the queued update can no longer be applied
	CURSOR cur_q IS
		SELECT	DISTINCT po_dst_number, bo_number, style_master_sku, color_number, size_number,
			dimension_number, vendor_pack, quantity_per_pack, pack_sku, receiver_number
		  FROM	aalwrkq
		 WHERE	operation_code in (1,2); -- deletes can be queued, but should not ever be added as new WL items VI 168

	-- Select matching items from the worklist where the PO
	-- matches and bo matches and receiver nbr matches.
  -- nulls have already been replaced with zeroes.
	-- Released POs are excluded.  These are handled by
	-- the worklist rebuild.
	CURSOR cur_wl_by_po_bo(po_id worklist.po_nbr%TYPE, bo_id worklist.bo_nbr%TYPE, rcv_id worklist.receiving_id%TYPE) IS
		SELECT	DISTINCT wl_key
		  FROM	WORKLIST wl
		 WHERE	wl.po_nbr = po_id
		   AND	wl.bo_nbr = bo_id
       AND  wl.receiving_id = rcv_id
		   AND  wl.status_code <> const_released;

	old_status		    worklist.status_code%TYPE;
	new_wlkey		    worklist.wl_key%TYPE;
  po_wlkey            worklist.wl_key%TYPE;
	local_alloc_nbr		worklist.alloc_nbr%TYPE;
	v_bSuccess		    BOOLEAN;

	v_PackID		    worklist.pack_id%TYPE;
	v_ShapeType		    NUMBER;
	v_nbr_packs		    worklist.nbr_packs%TYPE;
	v_on_order_packs	worklist.on_order_packs%TYPE;
	v_wlkeycount    	NUMBER;
  UserLoginStatus system_status.system_stat_value%TYPE; --used to restore system status after rebuild


BEGIN
  /* The last phase of the WorkList rebuild consists of updates to all remaining lines. */
  /* Disable logins until that phase is complete.                                       */
  select system_stat_value
    into UserLoginStatus
    from system_status
   where system_stat_code = 'LOGINS_ALLOWED';

  IF (p_bCalledForRebuild = TRUE) THEN
     UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = 'N' WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
     COMMIT;
  END IF;

	--
	-- Loop through the aalwrkq and process the header records
	-- If there is no worklist key for the combination of
	-- po_nbr, bo_nbr, style_master_sku, color/size/dimension, then
	-- create a new worklist key and insert the record into the worklist table
	-- Also, flag the new record with a trouble code 'DUP'. Normally, records should
	-- only be updated.
	-- After processing all the wrkq records, insert these records into regular
	-- aalwrk table for normal processing, where detail records are processed.
	-- In the first loop, only header records are created. In the regular aalwrk cursor,
	-- the detail records are processed.
	--
	FOR cur_rec IN cur_q LOOP
		proc_wlkey(cur_rec.po_dst_number,
			   cur_rec.bo_number,
			   cur_rec.style_master_sku,
			   cur_rec.color_number,
			   cur_rec.size_number,
			   cur_rec.dimension_number,
			   cur_rec.vendor_pack,
			   cur_rec.quantity_per_pack,
			   cur_rec.pack_sku,
               cur_rec.receiver_number,
			   v_packID,
			   v_ShapeType,
			   new_wlkey);

		--
		-- If the Worklist key is not found, get the next work list key
		-- But this record will be marked DUPLICATE as this shouldn't have
		-- happened.
		--
		IF new_wlkey = 0 THEN
			new_wlkey	:= func_next_wlkey();

			INSERT INTO worklist (alloc_nbr, wl_key, po_nbr, bo_nbr,
					      style_master_sku,	color_nbr, status_code,
					      shape_type, receiving_id, create_date, status_timestamp)
				 	VALUES (0, new_wlkey,
						 NVL(cur_rec.po_dst_number, 0),
						 NVL(cur_rec.bo_number, 0),
						 NVL(cur_rec.style_master_sku, 0),
						 cur_rec.color_number,
						 const_available_to_allocate,
						 v_ShapeType,
    				     NVL(cur_rec.receiver_number, 0),
 						 SYSDATE,
						 SYSDATE);


			UPDATE	worklist
			   SET	trouble_code= 'DUP'
			 WHERE	status_code<> const_in_progress
			   AND	wl_key		= new_wlkey;
		END IF;
	END LOOP;

-- This puts everything back into the temp table for processing, which handles the detail
-- record updates, as well as the queued deletes.  Header record inserts were already handled, as queued
-- header record inserts must be tagged as 'DUP', since that is the only type of insert that can get
-- queued (any real insert could not have been in-progress to cause a queue record)
	INSERT INTO	aalwrk
		(SELECT	*
		   FROM	aalwrkq);



	DELETE aalwrkq;

	FOR r_WLLine IN cur_addupd LOOP
		proc_wlkey (r_WLLine.po_dst_number,
			    r_WLLine.bo_number,
			    r_WLLine.style_master_sku,
			    r_WLLine.color_number,
			    r_WLLine.size_number,
			    r_WLLine.dimension_number,
			    r_WLLine.vendor_pack,
			    r_WLLine.quantity_per_pack,
			    r_WLLine.pack_sku,
                r_WLLine.receiver_number,
			    v_packID,
			    v_ShapeType,
			    new_wlkey);

     		IF new_wlkey = 0 THEN
    			new_wlkey := func_next_wlkey ();

    			INSERT INTO worklist (alloc_nbr, wl_key, po_nbr, bo_nbr,
	    				      style_master_sku, product_nbr, product_name, color_nbr, status_code,
		    			      shape_type, receiving_ID, create_date, status_timestamp, trouble_code)
			    	      VALUES (0, new_wlkey,
				    		 NVL (r_WLLine.po_dst_number, 0),
					    	 NVL (r_WLLine.bo_number, 0),
    						 NVL (r_WLLine.style_master_sku, 0),
    						 func_product_nbr (r_WLLine.style_master_sku),
    						 func_style_name(r_WLLine.department_number,
    						 r_WLLine.subdepartment_number,
    						 r_WLLine.class_number,
                             r_WLLine.item_group_number,
    						 r_WLLine.subclass_number,
                             r_WLLine.choice_number,
    						 r_WLLine.style_master_sku),
	    					 r_WLLine.color_number,
		    				 const_available_to_allocate,
			    			 v_ShapeType,
                             NVL(r_WLLine.receiver_number, 0),
					    	 SYSDATE,
    						 SYSDATE,
                             r_WLLine.trouble_code);

		END IF;			-- new_wlkey is 0

		-- Checks if current worklist is in progress and adds that information
		-- to aalwrkq for next processing of the worklist.
		IF func_wl_status_code (new_wlkey) = const_in_progress THEN
			-- saves worklist for next time
				INSERT INTO aalwrkq
					(operation_code, merchandise_source, po_dst_number,
					bo_number, color_number, color_name,
					size_number, size_name,	dimension_number,
					dimension_name, line_sequence,	exp_receipt_date,
					purch_vendor_number, purch_vendor_name,	style_master_sku,
					product_name, available_packs,
					on_order_packs,	quantity_per_pack,
					default_warehouse, receiver_number, receipt_date,
					department_number, department_name, subdepartment_number,
					subdepartment_name, class_number, class_name,item_group_number,item_group_name,
					subclass_number, subclass_name,choice_number,choice_name, coord_group,
					coord_group_name, retail_price, shipping_comments,
					po_note_1, po_note_2, po_note_3,
					z_open_01, z_open_02, z_open_03,
					z_open_04, z_open_05, z_open_06,
					z_open_07, z_open_08, z_open_09,
					z_open_10, z_open_11, z_open_12,
					z_open_13, z_open_14, z_open_15,
					pack_sku, vendor_pack, trouble_code,
                    po_ad_DATE, otb_period, otb_week, ship_DATE,
					dest_whse, prim_vend_flowcode, trans_ad_DATE,
					in_store_DATE, replen_flag, sku_status,
                    ATTR_1_CODE, ATTR_1_DESC,
                    ATTR_2_CODE, ATTR_2_DESC,
                    ATTR_3_CODE, ATTR_3_DESC,
                    ATTR_4_CODE, ATTR_4_DESC,
                    ATTR_5_CODE, ATTR_5_DESC,
                    ATTR_6_CODE, ATTR_6_DESC,
                    ATTR_7_CODE, ATTR_7_DESC,
                    ATTR_8_CODE, ATTR_8_DESC,
                    ATTR_9_CODE, ATTR_9_DESC,
                    ATTR_10_CODE, ATTR_10_DESC,
                    ATTR_11_CODE, ATTR_11_DESC,
                    ATTR_12_CODE, ATTR_12_DESC,
                    MODEL_NAME)
				 VALUES (r_WLLine.operation_code, r_WLLine.merchandise_source, r_WLLine.po_dst_number,
					r_WLLine.bo_number, r_WLLine.color_number, r_WLLine.color_name,
					r_WLLine.size_number, r_WLLine.size_name, r_WLLine.dimension_number,
					r_WLLine.dimension_name, r_WLLine.line_sequence, r_WLLine.exp_receipt_date,
					r_WLLine.purch_vendor_number, r_WLLine.purch_vendor_name, r_WLLine.style_master_sku,
					r_WLLine.product_name, r_WLLine.available_packs,
					r_WLLine.on_order_packs, r_WLLine.quantity_per_pack,
					r_WLLine.default_warehouse, r_WLLine.receiver_number, r_WLLine.receipt_date,
					r_WLLine.department_number, r_WLLine.department_name, r_WLLine.subdepartment_number,
					r_WLLine.subdepartment_name, r_WLLine.class_number, r_WLLine.class_name, r_WLLine.item_group_number, r_WLLine.item_group_name,
					r_WLLine.subclass_number, r_WLLine.subclass_name, r_WLLine.choice_number, r_WLLine.choice_name, r_WLLine.coord_group,
					r_WLLine.coord_group_name, r_WLLine.retail_price, r_WLLine.shipping_comments,
					r_WLLine.po_note_1, r_WLLine.po_note_2, r_WLLine.po_note_3,
					r_WLLine.z_open_01, r_WLLine.z_open_02, r_WLLine.z_open_03,
					r_WLLine.z_open_04, r_WLLine.z_open_05, r_WLLine.z_open_06,
					r_WLLine.z_open_07, r_WLLine.z_open_08, r_WLLine.z_open_09,
					r_WLLine.z_open_10, r_WLLine.z_open_11, r_WLLine.z_open_12,
					r_WLLine.z_open_13, r_WLLine.z_open_14, r_WLLine.z_open_15,
					r_WLLine.pack_sku, r_WLLine.vendor_pack, r_WLLine.trouble_code,
                    r_WLLine.po_ad_DATE, r_WLLine.otb_period, r_WLLine.otb_week,
					r_WLLine.ship_DATE, r_WLLine.dest_whse, r_WLLine.prim_vend_flowcode,
					r_WLLine.trans_ad_DATE,	r_WLLine.in_store_DATE, r_WLLine.replen_flag,
					r_WLLine.sku_status,
                    r_WLLine.ATTR_1_CODE, r_WLLine.ATTR_1_DESC,
                    r_WLLine.ATTR_2_CODE, r_WLLine.ATTR_2_DESC,
                    r_WLLine.ATTR_3_CODE, r_WLLine.ATTR_3_DESC,
                    r_WLLine.ATTR_4_CODE, r_WLLine.ATTR_4_DESC,
                    r_WLLine.ATTR_5_CODE, r_WLLine.ATTR_5_DESC,
                    r_WLLine.ATTR_6_CODE, r_WLLine.ATTR_6_DESC,
                    r_WLLine.ATTR_7_CODE, r_WLLine.ATTR_7_DESC,
                    r_WLLine.ATTR_8_CODE, r_WLLine.ATTR_8_DESC,
                    r_WLLine.ATTR_9_CODE, r_WLLine.ATTR_9_DESC,
                    r_WLLine.ATTR_10_CODE, r_WLLine.ATTR_10_DESC,
                    r_WLLine.ATTR_11_CODE, r_WLLine.ATTR_11_DESC,
                    r_WLLine.ATTR_12_CODE, r_WLLine.ATTR_12_DESC,
                    r_WLLine.MODEL_NAME);
		ELSE				-- go ahead and process



       -- Except for true vendor packs, the
       -- nbr of packs is actually total qty divided by qty per pack.  This
       -- handles the fact that MMS sends total quantity available for items
       -- where inner pack > 1, and AMIS converts it into packs
       -- This is true for both available and on order packs
       -- this will get multiplied back out when results go back to MMS.
          IF r_WLLine.vendor_pack IS NOT NULL THEN
             v_nbr_packs := r_WLLine.available_packs;
             v_on_order_packs := NVL(r_WLLine.on_order_packs, 0);
          ELSE
             v_nbr_packs := (NVL(r_WLLine.available_packs, 0) / NVL(r_WLLine.quantity_per_pack,1));
             v_on_order_packs := (NVL(r_WLLine.on_order_packs, 0) / NVL(r_WLLine.quantity_per_pack,1));
          END IF;

			UPDATE worklist
    			      SET receiving_date = func_is_valid_date (r_WLLine.receipt_date),
    			      	  dept_nbr = r_WLLine.department_number,
    			      	  class_nbr = r_WLLine.class_number,
                          item_group_nbr = r_WLLine.item_group_number,
    			      	  subclass_nbr = r_WLLine.subclass_number,
                          choice_nbr = r_WLLine.choice_number,
    			      	  subdept_nbr = r_WLLine.subdepartment_number,
    			      	  dept_name = r_WLLine.department_name,
    			      	  subdept_name	= r_WLLine.subdepartment_name,
    			      	  class_name = r_WLLine.class_name,
                          item_group_name = r_WLLine.item_group_name,
    			      	  subclass_name 	= r_WLLine.subclass_name,
                          choice_name     = r_WLLine.choice_name,
                          color_name = r_WLLine.color_name,
                          po_line_comments = r_WLLine.po_note_1 || r_WLLine.po_note_2 || r_WLLine.po_note_3,
                          qty_per_pack = r_WLLine.quantity_per_pack,
                          retail_price = r_WLLine.retail_price,
                          source_whse = r_WLLine.default_warehouse,
                          destination_whse = r_WLLine.dest_whse,
                          vendor_name = r_WLLine.purch_vendor_name,
                          vendor_nbr = r_WLLine.purch_vendor_number,
                          coord_group = r_WLLine.coord_group,
                          coord_group_name = r_WLLine.coord_group_name,
                          merch_status_code = r_WLLine.merchandise_source,
                          merch_status_desc	= func_merch_status_name(r_WLLine.merchandise_source),
                          on_order_packs = v_on_order_packs,
                          nbr_packs = v_nbr_packs,
                          in_dc_date = func_is_valid_date(r_WLLine.exp_receipt_date),
                          vendor_pack_id = r_WLLine.vendor_pack,
                    --Pack ID gets qty per pack appended to it if qty per pack > 1 and vendor pack is null
                    -- this is done when the wl key is generated
                          pack_id = v_packID,
                          z_open_01  = r_WLLine.z_open_01,
  				          z_open_02 = r_WLLine.z_open_02,
  				          z_open_03 = r_WLLine.z_open_03,
  				          z_open_04 = r_WLLine.z_open_04,
  				          z_open_05 = r_WLLine.z_open_05,
  				          z_open_06 = r_WLLine.z_open_06,
  				          z_open_07 = r_WLLine.z_open_07,
  				          z_open_08 = r_WLLine.z_open_08,
  				          z_open_09 = r_WLLine.z_open_09,
  				          z_open_10 = r_WLLine.z_open_10,
  				          z_open_11 = r_WLLine.z_open_11,
  				          z_open_12 = r_WLLine.z_open_12,
  				          z_open_13 = r_WLLine.z_open_13,
  				          z_open_14 = r_WLLine.z_open_14,
  				          z_open_15 = r_WLLine.z_open_15,
                          po_ad_DATE = TO_DATE(r_WLLine.po_ad_DATE, 'YYYYMMDD'),
                          otb_period = r_WLLine.otb_period,
                          otb_week = r_WLLine.otb_week,
                          ship_DATE = TO_DATE(r_WLLine.ship_DATE, 'YYYYMMDD'),
                          prim_vend_flowcode = r_WLLine.prim_vend_flowcode,
                          trans_ad_DATE = TO_DATE(r_WLLine.trans_ad_DATE, 'YYYYMMDD'),
                          in_store_DATE = TO_DATE(r_WLLine.in_store_DATE, 'YYYYMMDD'),
                          replen_flag = r_WLLine.replen_flag,
                          sku_status = r_WLLine.sku_status,
                          ATTR_1_CODE = r_WLLine.ATTR_1_CODE,
                          ATTR_1_DESC = r_WLLine.ATTR_1_DESC,
                          ATTR_2_CODE = r_WLLine.ATTR_2_CODE,
                          ATTR_2_DESC = r_WLLine.ATTR_2_DESC,
                          ATTR_3_CODE = r_WLLine.ATTR_3_CODE,
                          ATTR_3_DESC = r_WLLine.ATTR_3_DESC,
                          ATTR_4_CODE = r_WLLine.ATTR_4_CODE,
                          ATTR_4_DESC = r_WLLine.ATTR_4_DESC,
                          ATTR_5_CODE = r_WLLine.ATTR_5_CODE,
                          ATTR_5_DESC = r_WLLine.ATTR_5_DESC,
                          ATTR_6_CODE = r_WLLine.ATTR_6_CODE,
                          ATTR_6_DESC = r_WLLine.ATTR_6_DESC,
                          ATTR_7_CODE = r_WLLine.ATTR_7_CODE,
                          ATTR_7_DESC = r_WLLine.ATTR_7_DESC,
                          ATTR_8_CODE = r_WLLine.ATTR_8_CODE,
                          ATTR_8_DESC = r_WLLine.ATTR_8_DESC,
                          ATTR_9_CODE = r_WLLine.ATTR_9_CODE,
                          ATTR_9_DESC = r_WLLine.ATTR_9_DESC,
                          ATTR_10_CODE = r_WLLine.ATTR_10_CODE,
                          ATTR_10_DESC = r_WLLine.ATTR_10_DESC,
                          ATTR_11_CODE = r_WLLine.ATTR_11_CODE,
                          ATTR_11_DESC = r_WLLine.ATTR_11_DESC,
                          ATTR_12_CODE = r_WLLine.ATTR_12_CODE,
                          ATTR_12_DESC = r_WLLine.ATTR_12_DESC,
                          MODEL_NAME = r_WLLine.MODEL_NAME
			    WHERE wl_key = new_wlkey;

                -- If this is the FIRST instance of this ASN line that we've received, release the
                -- PO line if it is already allocated.  We should ony do this on the first ASN instance
                -- because we don't want to alter the 'PO Balance' worklist line that was added when we
                -- received a prior ASN line.

            	IF (r_WLLine.vendor_pack is null) THEN -- not vendor pack
                BEGIN
                  IF (r_WLLine.color_number is null) THEN -- not colored; style only
                    BEGIN
                      SELECT	count(wl_key)/*+ index(WORKLIST_MAIN_KEY1_IDX) */
                    	  INTO	v_wlkeycount
                    	  FROM	worklist
                    	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                    	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
                   	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                    	   AND	color_nbr is null
                    	   AND	shape_type	= v_ShapeType
                    	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                    END;
                  ELSE -- colored; use as part of key
                    BEGIN
                    	SELECT	count(wl_key)/*+ index(WORKLIST_MAIN_KEY1_IDX) */
                    	  INTO	v_wlkeycount
                    	  FROM	worklist
                    	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                    	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
                   	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                    	   AND	color_nbr = NVL(r_WLLine.color_number, 'ColorValue')
                    	   AND	shape_type	= v_ShapeType
                    	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                    END;
                  END IF;
                END;
              ELSE -- vendor pack; don't use color in key, but use vendor pack
                BEGIN
                	SELECT	count(wl_key) /*+ index(WORKLIST_MAIN_KEY2_IDX) */
                	  INTO	v_wlkeycount
                	  FROM	worklist
                	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
              	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                	   AND	shape_type	= v_ShapeType
                	   AND  vendor_pack_id  = r_WLLine.vendor_pack
                	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                END;
              END IF;


                IF NVL(r_WLLine.receiver_number,0) <> 0 and v_wlkeycount = 1 THEN
            		proc_wlkey (r_WLLine.po_dst_number,
	        		            r_WLLine.bo_number,
        		        	    r_WLLine.style_master_sku,
		        	            r_WLLine.color_number,
			                    r_WLLine.size_number,
           			            r_WLLine.dimension_number,
        	        		    r_WLLine.vendor_pack,
		                	    r_WLLine.quantity_per_pack,
			                    r_WLLine.pack_sku,
                                0,
            	    		    v_packID,
	            	    	    v_ShapeType,
		    	                po_wlkey);

                    -- If the PO line was found...
                    IF po_wlkey <> 0 then
                        SELECT alloc_nbr, status_code into local_alloc_nbr, old_status FROM	worklist WHERE wl_key = po_wlkey;

                        -- If allocation is Unapproved, set it to Approved.
                        -- NOTE: Allocations should not normally have lines set to different status.
                        --       In this case we know we are opening a window of opportunity for an error
                        --       to cause problems, but we aim to recover from it if the Release fails.
                        --       If the release is successful the remaining lines will be moved to another allocation.
                        IF old_status = const_unapproved THEN
                            UPDATE worklist set status_code = const_approved where wl_key = po_wlkey;
                        END IF;

                        -- If status was Approved or Unapproved (in which case it will now be approved)...
                        IF old_status in (const_approved, const_unapproved) then
                        -- Release matching worklist line.

                          IF  AllocAutoRelease.ReleaseMultiWorklistLines(po_wlkey) = 0 then
                            UPDATE Worklist Set Allocator_Comments = 'Special Interface Release' where wl_key = po_wlkey;
                            AllocCAQ.DecrementCAQEx(local_alloc_nbr);
                          ELSE
                            -- Release failed, so if the original status was unapproved, move this line back to
                            -- unapproved in order to match the rest of the allocation.
                            IF old_status = const_unapproved THEN
                                UPDATE worklist set status_code = const_unapproved where wl_key = po_wlkey;
                            END IF;
                          END IF;
                        END IF;
                    END IF;
                END IF;
		END IF;
		COMMIT;
		UpdateWLShapeTables(new_wlkey, r_WLLine, v_packID, v_nbr_packs, v_on_order_packs);
	END LOOP;
	/* end of update loop */

	DELETE FROM wl_del;

	FOR curr_del_rec IN cur_del LOOP
		-- Allow the delete of a PO or parital PO by matching as many key fields
		-- as are sent from MMS.  This is to fix VI 161, where an individual color/size
		-- deleted from a PO causes the entire PO/Color WL key to be deleted until it was
		-- later restored during the WorkList rebuid due to the other sizes still being present.
		IF (curr_del_rec.po_dst_number IS NOT NULL)
		  AND (curr_del_rec.style_master_sku IS NOT NULL) THEN
			-- If we specify a sku number, that means we're giving low level details of a PO line
      -- item to delete.
  			proc_aalwrk_do_wildcard_del (
				curr_del_rec.po_dst_number,
				curr_del_rec.bo_number,
        curr_del_rec.receiver_number,
        curr_del_rec.vendor_pack,
				curr_del_rec.color_number,
				curr_del_rec.size_number,
				curr_del_rec.dimension_number,
				curr_del_rec.style_master_sku);
		ELSIF (curr_del_rec.po_dst_number IS NOT NULL)
			  AND (curr_del_rec.style_master_sku IS NULL) THEN
			-- This is the deletion of an entire PO or ASN, so we have to loop
			-- through all the matching worklist items.
			FOR rec_wl_by_po_bo IN cur_wl_by_po_bo(NVL(curr_del_rec.po_dst_number,0), NVL(curr_del_rec.bo_number,0), NVL(curr_del_rec.receiver_number,0) ) LOOP
				proc_aalwrk_handle_del (rec_wl_by_po_bo.wl_key,
							curr_del_rec.po_dst_number,
							curr_del_rec.bo_number,
              curr_del_rec.receiver_number,
              curr_del_rec.vendor_pack,
					   	curr_del_rec.style_master_sku,
					   	curr_del_rec.color_number,
					   	curr_del_rec.size_number,
					   	curr_del_rec.dimension_number);
			END LOOP;
		END IF; -- if PO number is null, don't even attempt to process it.
	END LOOP;

	-- We have to commit before we attempt to delete from the worklist.
	COMMIT;

	-- Delete all occurances of the wl_keys in wl_del from the worklist and all shape tables.
	-- If this fails, will log an error and return false. May want to handle this....

  PrepareForWorkListDelete();
	v_bSuccess	:= AllocMMS.DeleteWLKeys(' IN (SELECT wl_key FROM wl_del)');

	-- Delete the temp table so that we can rerun this procedure for queue processing.
	DELETE aalwrk;

	COMMIT;

  /* The final phase of the rebuild is complete.  Restore user login status to its original state. */
  IF (p_bCalledForRebuild = TRUE) THEN
    UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = UserLoginStatus WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
    COMMIT;
  END IF;

END proc_aalwrk;

PROCEDURE UpdateWLShapeTables2(
	p_wlkey				IN worklist.wl_key%TYPE,
	p_aalwrk			IN aalwrk2%ROWTYPE,
  p_PackID IN worklist.pack_id%TYPE,
  p_NbrPacks IN aalwrk2.available_packs%TYPE,
  p_OrderPacks IN aalwrk2.on_order_packS%TYPE,
	p_bCalledForRebuild		IN BOOLEAN	DEFAULT FALSE )
IS
PRAGMA AUTONOMOUS_TRANSACTION;
	v_arrStatusError	log_table.status%TYPE	:= 'Shape Processing Error.';
	v_arrProcName		VARCHAR2(35)		:= 'UpdateWLShapeTables';
	v_ShapeTypeNbr		NUMBER;
BEGIN
	v_ShapeTypeNbr		:= get_shape_type(p_aalwrk.Dimension_Number, p_aalwrk.Size_number, p_aalwrk.Color_number);

	IF v_ShapeTypeNbr = const_style_shape THEN -- Style level
	  BEGIN
			UPDATE pack_style
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				PACK_ID = p_PackID,
				style_master_sku = p_aalwrk.style_master_sku,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
-- * GSM06 - Modified UpdateWLShapeTables,2 to use raw avail,onorder pack qty sent from MAGIC *
                avail_qty = p_aalwrk.available_packs,
                on_order_balance = p_aalwrk.on_order_packs,
				--avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				--on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
-- * GSM05 - Modified UpdateWLShapeTables,2 to update Pack_Style as 1to1 relationship to Worklist *
			--  AND PACK_ID = p_PackID
			;
      IF SQL%rowcount = 0 THEN
		INSERT
		  INTO pack_style
		       (wl_key,
			line_sequence,
			style_master_sku,
			pack_id,
			nbr_packs,
			qty_per_pack,
			avail_qty,
			on_order_balance,
			retail_price,
			po_line_comments)
		VALUES (p_wlkey,
            NVL(p_aalwrk.line_sequence, 0),
			p_aalwrk.style_master_sku,
			p_PackID,
			p_NbrPacks,
			p_aalwrk.quantity_per_pack,
-- * GSM06 - Modified UpdateWLShapeTables,2 to use raw avail,onorder pack qty sent from MAGIC *
            p_aalwrk.available_packs,
            p_aalwrk.on_order_packs,
			--p_aalwrk.quantity_per_pack * p_NbrPacks,
			--p_aalwrk.quantity_per_pack * p_OrderPacks,
			p_aalwrk.retail_price,
			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
      END IF;
--		EXCEPTION
--		   WHEN DUP_VAL_ON_INDEX THEN
	END;
	ELSIF v_ShapeTypeNbr = const_color_shape THEN -- Color level
	      BEGIN
		INSERT
		  INTO pack_color
		       (wl_key,
			line_sequence,
			style_master_sku,
			color_nbr,
			color_name,
			pack_id,
			nbr_packs,
			qty_per_pack,
			avail_qty,
			on_order_balance,
			retail_price,
			po_line_comments)
		VALUES (p_wlkey,
			NVL(p_aalwrk.line_sequence, 0),
            p_aalwrk.style_master_sku,
			p_aalwrk.color_number,
			p_aalwrk.color_name,
			p_PackID,
			p_NbrPacks,
			p_aalwrk.quantity_per_pack,
			p_aalwrk.quantity_per_pack * p_NbrPacks,
			p_aalwrk.quantity_per_pack * p_OrderPacks,
			p_aalwrk.retail_price,
			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
		EXCEPTION
		   WHEN DUP_VAL_ON_INDEX THEN
			UPDATE pack_color
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
               	style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number;
	      END;
	ELSIF v_ShapeTypeNbr = const_size_shape THEN -- Size level
	      BEGIN
		INSERT
		  INTO pack_size
		       (wl_key,
			line_sequence,
			style_master_sku,
			color_nbr,
			color_name,
			size_nbr,
			size_name,
			pack_id,
			nbr_packs,
			qty_per_pack,
			avail_qty,
			on_order_balance,
			retail_price,
			po_line_comments)
		VALUES (p_wlkey,
			NVL(p_aalwrk.line_sequence, 0),
			p_aalwrk.style_master_sku,
			p_aalwrk.color_number,
			p_aalwrk.color_name,
			p_aalwrk.size_number,
			p_aalwrk.size_name,
			p_PackID,
			p_NbrPacks,
			p_aalwrk.quantity_per_pack,
			p_aalwrk.quantity_per_pack * p_NbrPacks,
			p_aalwrk.quantity_per_pack * p_OrderPacks,
			p_aalwrk.retail_price,
			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
		EXCEPTION
		   WHEN DUP_VAL_ON_INDEX THEN
			UPDATE pack_size
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				size_name = p_aalwrk.size_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number
			  AND size_nbr = p_aalwrk.size_number;
	      END;
	ELSIF v_ShapeTypeNbr = const_dimension_shape THEN -- Dimension level
	      BEGIN
		INSERT
		  INTO pack_dimension
		       (wl_key,
			line_sequence,
			style_master_sku,
			color_nbr,
			color_name,
			size_nbr,
			size_name,
			dim_nbr,
			dim_name,
			pack_id,
			nbr_packs,
			qty_per_pack,
			avail_qty,
			on_order_balance,
			retail_price,
			po_line_comments)
		VALUES (p_wlkey,
			NVL(p_aalwrk.line_sequence, 0),
			p_aalwrk.style_master_sku,
			p_aalwrk.color_number,
			p_aalwrk.color_name,
			p_aalwrk.size_number,
			p_aalwrk.size_name,
			p_aalwrk.dimension_number,
			p_aalwrk.dimension_name,
			p_PackID,
			p_NbrPacks,
			p_aalwrk.quantity_per_pack,
			p_aalwrk.quantity_per_pack * p_NbrPacks,
			p_aalwrk.quantity_per_pack * p_OrderPacks,
			p_aalwrk.retail_price,
			p_aalwrk.po_note_1 || p_aalwrk.po_note_2 || p_aalwrk.po_note_3);
		EXCEPTION
		   WHEN DUP_VAL_ON_INDEX THEN
			UPDATE pack_dimension
			   SET  line_sequence = NVL(p_aalwrk.line_sequence, 0),
				style_master_sku = p_aalwrk.style_master_sku,
				color_name = p_aalwrk.color_name,
				size_name = p_aalwrk.size_name,
				dim_name = p_aalwrk.dimension_name,
				nbr_packs = p_NbrPacks,
				qty_per_pack = NVL(p_aalwrk.quantity_per_pack, 0),
				avail_qty = p_aalwrk.quantity_per_pack * p_NbrPacks,
				on_order_balance = p_aalwrk.quantity_per_pack * p_OrderPacks,
				retail_price = p_aalwrk.retail_price,
				po_line_comments = p_aalwrk.po_note_1 ||
						   p_aalwrk.po_note_2 ||
						   p_aalwrk.po_note_3
			WHERE wl_key = p_wlkey
			  AND PACK_ID = p_PackID
			  AND color_nbr = p_aalwrk.color_number
			  AND size_nbr = p_aalwrk.size_number
			  AND dim_nbr = p_aalwrk.dimension_number;
	      END;
	END IF;
	-- Check the status on the worklist for the record we are updating
	-- if it is approved or unapproved, then compare the old-avail_qty from worklist
	-- sum up with the new avail qty from the detail table and compare the old and new
	-- and if it is different, then mark them discrepent.
	COMMIT;
	sum_avail(p_wlkey);
	sum_oob(p_wlkey);

	COMMIT;
EXCEPTION
	WHEN OTHERS THEN
		ROLLBACK;
		LogError(v_arrStatusError, v_arrProcName || ': General Error [' || SQLERRM || '].');
END UpdateWLShapeTables2;

PROCEDURE proc_aalwrk2(p_bCalledForRebuild	IN BOOLEAN) AS
PRAGMA AUTONOMOUS_TRANSACTION;
	CURSOR cur_addupd IS
		SELECT	*
		  FROM	aalwrk2
		 WHERE	operation_code IN ('1', '2');

	CURSOR cur_del IS
		SELECT	*
		  FROM	aalwrk2
		 WHERE	operation_code = '3';

  -- This is a list of queued records that might cause new wl keys to be added,
  -- assuming that the queued update can no longer be applied
	CURSOR cur_q IS
		SELECT	DISTINCT po_dst_number, bo_number, style_master_sku, color_number, size_number,
			dimension_number, vendor_pack, quantity_per_pack, pack_sku, receiver_number
		  FROM	aalwrk2q
		 WHERE	operation_code in (1,2); -- deletes can be queued, but should not ever be added as new WL items VI 168

	-- Select matching items from the worklist where the PO
	-- matches and bo matches and receiver nbr matches.
  -- nulls have already been replaced with zeroes.
	-- Released POs are excluded.  These are handled by
	-- the worklist rebuild.
	CURSOR cur_wl_by_po_bo(po_id worklist.po_nbr%TYPE, bo_id worklist.bo_nbr%TYPE, rcv_id worklist.receiving_id%TYPE) IS
		SELECT	DISTINCT wl_key
		  FROM	WORKLIST wl
		 WHERE	wl.po_nbr = po_id
		   AND	wl.bo_nbr = bo_id
       AND  wl.receiving_id = rcv_id
		   AND  wl.status_code <> const_released;

	old_status		    worklist.status_code%TYPE;
	new_wlkey		    worklist.wl_key%TYPE;
  po_wlkey            worklist.wl_key%TYPE;
	local_alloc_nbr		worklist.alloc_nbr%TYPE;
	v_bSuccess		    BOOLEAN;

	v_PackID		    worklist.pack_id%TYPE;
	v_ShapeType		    NUMBER;
	--v_nbr_packs		    worklist.nbr_packs%TYPE;
	--v_on_order_packs	worklist.on_order_packs%TYPE;
  v_nbr_packs		    aalwrk2.available_packs%TYPE;
	v_on_order_packs	aalwrk2.on_order_packs%TYPE;
	v_wlkeycount    	NUMBER;
  UserLoginStatus system_status.system_stat_value%TYPE; --used to restore system status after rebuild


BEGIN
  /* The last phase of the WorkList rebuild consists of updates to all remaining lines. */
  /* Disable logins until that phase is complete.                                       */
  select system_stat_value
    into UserLoginStatus
    from system_status
   where system_stat_code = 'LOGINS_ALLOWED';

  IF (p_bCalledForRebuild = TRUE) THEN
     UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = 'N' WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
     COMMIT;
  END IF;

	--
	-- Loop through the aalwrkq and process the header records
	-- If there is no worklist key for the combination of
	-- po_nbr, bo_nbr, style_master_sku, color/size/dimension, then
	-- create a new worklist key and insert the record into the worklist table
	-- Also, flag the new record with a trouble code 'DUP'. Normally, records should
	-- only be updated.
	-- After processing all the wrkq records, insert these records into regular
	-- aalwrk table for normal processing, where detail records are processed.
	-- In the first loop, only header records are created. In the regular aalwrk cursor,
	-- the detail records are processed.
	--
	FOR cur_rec IN cur_q LOOP
		proc_wlkey(cur_rec.po_dst_number,
			   cur_rec.bo_number,
			   cur_rec.style_master_sku,
			   cur_rec.color_number,
			   cur_rec.size_number,
			   cur_rec.dimension_number,
			   cur_rec.vendor_pack,
			   cur_rec.quantity_per_pack,
			   cur_rec.pack_sku,
               cur_rec.receiver_number,
			   v_packID,
			   v_ShapeType,
			   new_wlkey);

		--
		-- If the Worklist key is not found, get the next work list key
		-- But this record will be marked DUPLICATE as this shouldn't have
		-- happened.
		--

        v_ShapeType := get_shape_type(cur_rec.dimension_number,
                    cur_rec.size_number,
									  cur_rec.color_number);

        IF (cur_rec.vendor_pack IS NULL) AND (cur_rec.quantity_per_pack > 1) THEN
	   --
	   -- If vendor pack id is null and if qty_per_pack is greater than
	   -- or equal to 1, then append qty_per_pack to the pack id.
	   --
          v_packID := RTRIM(cur_rec.pack_sku) || '_' || cur_rec.quantity_per_pack;
        ELSE
          v_packID := RTRIM(cur_rec.pack_sku);
        END IF;

		IF new_wlkey = 0 THEN
			new_wlkey	:= func_next_wlkey();

			INSERT INTO worklist (alloc_nbr, wl_key, po_nbr, bo_nbr,
					      style_master_sku,	color_nbr, status_code,
					      shape_type, receiving_id, create_date, status_timestamp)
				 	VALUES (0, new_wlkey,
						 NVL(cur_rec.po_dst_number, 0),
						 NVL(cur_rec.bo_number, 0),
						 NVL(cur_rec.style_master_sku, 0),
						 cur_rec.color_number,
						 const_available_to_allocate,
						 v_ShapeType,
    				     NVL(cur_rec.receiver_number, 0),
 						 SYSDATE,
						 SYSDATE);


			UPDATE	worklist
			   SET	trouble_code= 'DUP'
			 WHERE	status_code<> const_in_progress
			   AND	wl_key		= new_wlkey;
		END IF;
	END LOOP;

-- This puts everything back into the temp table for processing, which handles the detail
-- record updates, as well as the queued deletes.  Header record inserts were already handled, as queued
-- header record inserts must be tagged as 'DUP', since that is the only type of insert that can get
-- queued (any real insert could not have been in-progress to cause a queue record)
	INSERT INTO	aalwrk2
		(SELECT	*
		   FROM	aalwrk2q);



	DELETE aalwrk2q;

	FOR r_WLLine IN cur_addupd LOOP
		proc_wlkey (r_WLLine.po_dst_number,
			    r_WLLine.bo_number,
			    r_WLLine.style_master_sku,
			    r_WLLine.color_number,
			    r_WLLine.size_number,
			    r_WLLine.dimension_number,
			    r_WLLine.vendor_pack,
			    r_WLLine.quantity_per_pack,
			    r_WLLine.pack_sku,
          r_WLLine.receiver_number,
			    v_packID,
			    v_ShapeType,
			    new_wlkey);

        v_ShapeType := get_shape_type(r_WLLine.dimension_number,
		                              r_WLLine.size_number,
									  r_WLLine.color_number);

        IF (r_WLLine.vendor_pack IS NULL) AND (r_WLLine.quantity_per_pack > 1) THEN
	   --
	   -- If vendor pack id is null and if qty_per_pack is greater than
	   -- or equal to 1, then append qty_per_pack to the pack id.
	   --
          v_packID := RTRIM(r_WLLine.pack_sku) || '_' || r_WLLine.quantity_per_pack;
        ELSE
          v_packID := RTRIM(r_WLLine.pack_sku);
        END IF;

     		IF new_wlkey = 0 THEN
    			new_wlkey := func_next_wlkey ();

    			INSERT INTO worklist (alloc_nbr, wl_key, po_nbr, bo_nbr,
	    				      style_master_sku, product_nbr, product_name, color_nbr, status_code,
		    			      shape_type, receiving_ID, create_date, status_timestamp, trouble_code)
			    	      VALUES (0, new_wlkey,
				    		 NVL (r_WLLine.po_dst_number, 0),
					    	 NVL (r_WLLine.bo_number, 0),
    						 NVL (r_WLLine.style_master_sku, 0),
    						 func_product_nbr (r_WLLine.style_master_sku),
    						 func_style_name(r_WLLine.department_number,
    						 	                  	 r_WLLine.subdepartment_number,
    						 	                  	 r_WLLine.class_number,
                                                     r_WLLine.item_group_number,
    						 		                 r_WLLine.subclass_number,
                                                     r_WLLine.choice_number,
    						 	                  	r_WLLine.style_master_sku),
	    					 r_WLLine.color_number,
		    				 const_available_to_allocate,
			    			 v_ShapeType,
                             NVL(r_WLLine.receiver_number, 0),
					    	 SYSDATE,
    						 SYSDATE,
                 r_WLLine.trouble_code);

		END IF;			-- new_wlkey is 0

		-- Checks if current worklist is in progress and adds that information
		-- to aalwrkq for next processing of the worklist.
		IF func_wl_status_code (new_wlkey) = const_in_progress THEN
			-- saves worklist for next time
				INSERT INTO aalwrk2q
					(operation_code, merchandise_source, po_dst_number,
					bo_number, color_number, color_name,
					size_number, size_name,	dimension_number,
					dimension_name, line_sequence,	exp_receipt_date,
					purch_vendor_number, purch_vendor_name,	style_master_sku,
					product_name, available_packs,
					on_order_packs,	quantity_per_pack,
					default_warehouse, receiver_number, receipt_date,
					department_number, department_name, subdepartment_number,
					subdepartment_name, class_number, class_name,item_group_number,item_group_name,
					subclass_number, subclass_name,choice_number,choice_name, coord_group,
					coord_group_name, retail_price, shipping_comments,
					po_note_1, po_note_2, po_note_3,
					z_open_01, z_open_02, z_open_03,
					z_open_04, z_open_05, z_open_06,
					z_open_07, z_open_08, z_open_09,
					z_open_10, z_open_11, z_open_12,
					z_open_13, z_open_14, z_open_15,
					pack_sku, vendor_pack, trouble_code,
          po_ad_DATE, otb_period, otb_week, ship_DATE,
					dest_whse, prim_vend_flowcode, trans_ad_DATE,
					in_store_DATE, replen_flag, sku_status)
				 VALUES (r_WLLine.operation_code, r_WLLine.merchandise_source, r_WLLine.po_dst_number,
					r_WLLine.bo_number, r_WLLine.color_number, r_WLLine.color_name,
					r_WLLine.size_number, r_WLLine.size_name, r_WLLine.dimension_number,
					r_WLLine.dimension_name, r_WLLine.line_sequence, r_WLLine.exp_receipt_date,
					r_WLLine.purch_vendor_number, r_WLLine.purch_vendor_name, r_WLLine.style_master_sku,
					r_WLLine.product_name, r_WLLine.available_packs,
					r_WLLine.on_order_packs, r_WLLine.quantity_per_pack,
					r_WLLine.default_warehouse, r_WLLine.receiver_number, r_WLLine.receipt_date,
					r_WLLine.department_number, r_WLLine.department_name, r_WLLine.subdepartment_number,
					r_WLLine.subdepartment_name, r_WLLine.class_number, r_WLLine.class_name, r_WLLine.item_group_number, r_WLLine.item_group_name,
					r_WLLine.subclass_number, r_WLLine.subclass_name, r_WLLine.choice_number, r_WLLine.choice_name, r_WLLine.coord_group,
					r_WLLine.coord_group_name, r_WLLine.retail_price, r_WLLine.shipping_comments,
					r_WLLine.po_note_1, r_WLLine.po_note_2, r_WLLine.po_note_3,
					r_WLLine.z_open_01, r_WLLine.z_open_02, r_WLLine.z_open_03,
					r_WLLine.z_open_04, r_WLLine.z_open_05, r_WLLine.z_open_06,
					r_WLLine.z_open_07, r_WLLine.z_open_08, r_WLLine.z_open_09,
					r_WLLine.z_open_10, r_WLLine.z_open_11, r_WLLine.z_open_12,
					r_WLLine.z_open_13, r_WLLine.z_open_14, r_WLLine.z_open_15,
					r_WLLine.pack_sku, r_WLLine.vendor_pack, r_WLLine.trouble_code,
          r_WLLine.po_ad_DATE, r_WLLine.otb_period, r_WLLine.otb_week,
					r_WLLine.ship_DATE, r_WLLine.dest_whse, r_WLLine.prim_vend_flowcode,
					r_WLLine.trans_ad_DATE,	r_WLLine.in_store_DATE, r_WLLine.replen_flag,
					r_WLLine.sku_status);
		ELSE				-- go ahead and process



       -- Except for true vendor packs, the
       -- nbr of packs is actually total qty divided by qty per pack.  This
       -- handles the fact that MMS sends total quantity available for items
       -- where inner pack > 1, and AMIS converts it into packs
       -- This is true for both available and on order packs
       -- this will get multiplied back out when results go back to MMS.
          IF r_WLLine.vendor_pack IS NOT NULL THEN
             v_nbr_packs := r_WLLine.available_packs;
             v_on_order_packs := NVL(r_WLLine.on_order_packs, 0);
          ELSE
             v_nbr_packs := (NVL(r_WLLine.available_packs, 0) / NVL(r_WLLine.quantity_per_pack,1));
             v_on_order_packs := (NVL(r_WLLine.on_order_packs, 0) / NVL(r_WLLine.quantity_per_pack,1));
          END IF;

			UPDATE worklist
    			      SET receiving_date = func_is_valid_date (r_WLLine.receipt_date),
    			      	  dept_nbr = r_WLLine.department_number,
    			      	  class_nbr = r_WLLine.class_number,
                          item_group_nbr = r_WLLine.item_group_number,
    			      	  subclass_nbr = r_WLLine.subclass_number,
                         choice_nbr = r_WLLine.choice_number,
    			      	  subdept_nbr = r_WLLine.subdepartment_number,
    			      	  dept_name = r_WLLine.department_name,
    			      	  subdept_name	= r_WLLine.subdepartment_name,
    			      	  class_name = r_WLLine.class_name,
                          item_group_name = r_WLLine.item_group_name,
    			      	  subclass_name 	= r_WLLine.subclass_name,
                          choice_name     = r_WLLine.choice_name,
                    color_name = r_WLLine.color_name,
                    po_line_comments = r_WLLine.po_note_1 ||
                                       r_WLLine.po_note_2 ||
                                  		 r_WLLine.po_note_3,
                    qty_per_pack = r_WLLine.quantity_per_pack,
                    retail_price = r_WLLine.retail_price,
                    source_whse = r_WLLine.default_warehouse,
                    destination_whse = r_WLLine.dest_whse,
                    vendor_name = r_WLLine.purch_vendor_name,
                    vendor_nbr = r_WLLine.purch_vendor_number,
                    coord_group = r_WLLine.coord_group,
                    coord_group_name = r_WLLine.coord_group_name,
                    merch_status_code = r_WLLine.merchandise_source,
                    merch_status_desc	= func_merch_status_name(r_WLLine.merchandise_source),
                    on_order_packs = v_on_order_packs,
                    nbr_packs = v_nbr_packs,
                    in_dc_date = func_is_valid_date(r_WLLine.exp_receipt_date),
                    vendor_pack_id = r_WLLine.vendor_pack,
                    --Pack ID gets qty per pack appended to it if qty per pack > 1 and vendor pack is null
                    -- this is done when the wl key is generated
                    pack_id = v_packID,
                    z_open_01  = r_WLLine.z_open_01,
  				          z_open_02 = r_WLLine.z_open_02,
  				          z_open_03 = r_WLLine.z_open_03,
  				          z_open_04 = r_WLLine.z_open_04,
  				          z_open_05 = r_WLLine.z_open_05,
  				          z_open_06 = r_WLLine.z_open_06,
  				          z_open_07 = r_WLLine.z_open_07,
  				          z_open_08 = r_WLLine.z_open_08,
  				          z_open_09 = r_WLLine.z_open_09,
  				          z_open_10 = r_WLLine.z_open_10,
  				          z_open_11 = r_WLLine.z_open_11,
  				          z_open_12 = r_WLLine.z_open_12,
  				          z_open_13 = r_WLLine.z_open_13,
  				          z_open_14 = r_WLLine.z_open_14,
  				          z_open_15 = r_WLLine.z_open_15,
                    po_ad_DATE = TO_DATE(r_WLLine.po_ad_DATE, 'YYYYMMDD'),
                    otb_period = r_WLLine.otb_period,
                    otb_week = r_WLLine.otb_week,
                    ship_DATE = TO_DATE(r_WLLine.ship_DATE, 'YYYYMMDD'),
                    prim_vend_flowcode = r_WLLine.prim_vend_flowcode,
                    trans_ad_DATE = TO_DATE(r_WLLine.trans_ad_DATE, 'YYYYMMDD'),
                    in_store_DATE = TO_DATE(r_WLLine.in_store_DATE, 'YYYYMMDD'),
                    replen_flag = r_WLLine.replen_flag,
                    sku_status = r_WLLine.sku_status,
                    model_name = r_WLLine.style_master_sku
			    WHERE wl_key = new_wlkey;

                -- If this is the FIRST instance of this ASN line that we've received, release the
                -- PO line if it is already allocated.  We should ony do this on the first ASN instance
                -- because we don't want to alter the 'PO Balance' worklist line that was added when we
                -- received a prior ASN line.

            	IF (r_WLLine.vendor_pack is null) THEN -- not vendor pack
                BEGIN
                  IF (r_WLLine.color_number is null) THEN -- not colored; style only
                    BEGIN
                      SELECT	count(wl_key)/*+ index(WORKLIST_MAIN_KEY1_IDX) */
                    	  INTO	v_wlkeycount
                    	  FROM	worklist
                    	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                    	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
                   	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                    	   AND	color_nbr is null
                    	   AND	shape_type	= v_ShapeType
                    	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                    END;
                  ELSE -- colored; use as part of key
                    BEGIN
                    	SELECT	count(wl_key)/*+ index(WORKLIST_MAIN_KEY1_IDX) */
                    	  INTO	v_wlkeycount
                    	  FROM	worklist
                    	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                    	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
                   	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                    	   AND	color_nbr = NVL(r_WLLine.color_number, 'ColorValue')
                    	   AND	shape_type	= v_ShapeType
                    	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                    END;
                  END IF;
                END;
              ELSE -- vendor pack; don't use color in key, but use vendor pack
                BEGIN
                	SELECT	count(wl_key) /*+ index(WORKLIST_MAIN_KEY2_IDX) */
                	  INTO	v_wlkeycount
                	  FROM	worklist
                	 WHERE	po_nbr	= NVL(r_WLLine.po_dst_number,0)
                	   AND	bo_nbr	= NVL(r_WLLine.bo_number,0)
              	     AND	style_master_sku = NVL(r_WLLine.style_master_sku, 0)
                	   AND	shape_type	= v_ShapeType
                	   AND  vendor_pack_id  = r_WLLine.vendor_pack
                	   AND	receiving_id = NVL(r_WLLine.receiver_number, 0);
                END;
              END IF;


                IF NVL(r_WLLine.receiver_number,0) <> 0 and v_wlkeycount = 1 THEN
            		proc_wlkey (r_WLLine.po_dst_number,
	        		            r_WLLine.bo_number,
        		        	    r_WLLine.style_master_sku,
		        	            r_WLLine.color_number,
			                    r_WLLine.size_number,
           			            r_WLLine.dimension_number,
        	        		    r_WLLine.vendor_pack,
		                	    r_WLLine.quantity_per_pack,
			                    r_WLLine.pack_sku,
                                0,
            	    		    v_packID,
	            	    	    v_ShapeType,
		    	                po_wlkey);

                    -- If the PO line was found...
                    IF po_wlkey <> 0 then
                        SELECT alloc_nbr, status_code into local_alloc_nbr, old_status FROM	worklist WHERE wl_key = po_wlkey;

                        -- If allocation is Unapproved, set it to Approved.
                        -- NOTE: Allocations should not normally have lines set to different status.
                        --       In this case we know we are opening a window of opportunity for an error
                        --       to cause problems, but we aim to recover from it if the Release fails.
                        --       If the release is successful the remaining lines will be moved to another allocation.
                        IF old_status = const_unapproved THEN
                            UPDATE worklist set status_code = const_approved where wl_key = po_wlkey;
                        END IF;

                        -- If status was Approved or Unapproved (in which case it will now be approved)...
                        IF old_status in (const_approved, const_unapproved) then
                        -- Release matching worklist line.

                          IF  AllocAutoRelease.ReleaseMultiWorklistLines(po_wlkey) = 0 then
                            UPDATE Worklist Set Allocator_Comments = 'Special Interface Release' where wl_key = po_wlkey;
                            AllocCAQ.DecrementCAQEx(local_alloc_nbr);
                          ELSE
                            -- Release failed, so if the original status was unapproved, move this line back to
                            -- unapproved in order to match the rest of the allocation.
                            IF old_status = const_unapproved THEN
                                UPDATE worklist set status_code = const_unapproved where wl_key = po_wlkey;
                            END IF;
                          END IF;
                        END IF;
                    END IF;
                END IF;
		END IF;
		COMMIT;
		UpdateWLShapeTables2(new_wlkey, r_WLLine, v_packID, v_nbr_packs, v_on_order_packs);
	END LOOP;
	/* end of update loop */

	DELETE FROM wl_del;

	FOR curr_del_rec IN cur_del LOOP
		-- Allow the delete of a PO or parital PO by matching as many key fields
		-- as are sent from MMS.  This is to fix VI 161, where an individual color/size
		-- deleted from a PO causes the entire PO/Color WL key to be deleted until it was
		-- later restored during the WorkList rebuid due to the other sizes still being present.
		IF (curr_del_rec.po_dst_number IS NOT NULL)
		  AND (curr_del_rec.style_master_sku IS NOT NULL) THEN
			-- If we specify a sku number, that means we're giving low level details of a PO line
      -- item to delete.
  			proc_aalwrk_do_wildcard_del (
				curr_del_rec.po_dst_number,
				curr_del_rec.bo_number,
        curr_del_rec.receiver_number,
        curr_del_rec.vendor_pack,
				curr_del_rec.color_number,
				curr_del_rec.size_number,
				curr_del_rec.dimension_number,
				curr_del_rec.style_master_sku);
		ELSIF (curr_del_rec.po_dst_number IS NOT NULL)
			  AND (curr_del_rec.style_master_sku IS NULL) THEN
			-- This is the deletion of an entire PO or ASN, so we have to loop
			-- through all the matching worklist items.
			FOR rec_wl_by_po_bo IN cur_wl_by_po_bo(NVL(curr_del_rec.po_dst_number,0), NVL(curr_del_rec.bo_number,0), NVL(curr_del_rec.receiver_number,0) ) LOOP
				proc_aalwrk_handle_del (rec_wl_by_po_bo.wl_key,
							curr_del_rec.po_dst_number,
							curr_del_rec.bo_number,
              curr_del_rec.receiver_number,
              curr_del_rec.vendor_pack,
					   	curr_del_rec.style_master_sku,
					   	curr_del_rec.color_number,
					   	curr_del_rec.size_number,
					   	curr_del_rec.dimension_number);
			END LOOP;
		END IF; -- if PO number is null, don't even attempt to process it.
	END LOOP;

	-- We have to commit before we attempt to delete from the worklist.
	COMMIT;

	-- Delete all occurances of the wl_keys in wl_del from the worklist and all shape tables.
	-- If this fails, will log an error and return false. May want to handle this....

  PrepareForWorkListDelete();
	v_bSuccess	:= AllocMMS.DeleteWLKeys(' IN (SELECT wl_key FROM wl_del)');

	-- Delete the temp table so that we can rerun this procedure for queue processing.
	DELETE aalwrk2;

	COMMIT;

  /* The final phase of the rebuild is complete.  Restore user login status to its original state. */
  IF (p_bCalledForRebuild = TRUE) THEN
    UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = UserLoginStatus WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
    COMMIT;
  END IF;

END proc_aalwrk2;

---  proc_aalrwk can only be run when there are no users running Arthur Allocation.
PROCEDURE proc_aalrwk(p_bCalledForRebuild	IN BOOLEAN) AS
	v_bSuccess			BOOLEAN;
  UserLoginStatus system_status.system_stat_value%TYPE; --used to restore system status after rebuild
BEGIN
  /* No users are to be in the system during the WorkList rebuild.  Although existing   */
  /* users cannot be kicked off the system, the below code will prevent users from      */
  /* logging in until the WorkList rebuild process is complete.                         */
  /*                                                                                    */
  /* Note that the WorkList rebuild takes place in three stages.  First, any lines that */
  /* aren't being refreshed are purged from the WorkList.  Next, CAQ is rebuilt based on*/
  /* any existing approved/unapproved allocations.  Last, the data for remaining lines  */
  /* is refreshed by the execution of proc_aalwrk using the entire WorkList as input.   */
  /* The middle stage of the WorkList rebuild process is the most succeptable to data   */
  /* integrity compromization due to user activity.                                     */
  /*                                                                                    */
  /* Following the WorkList rebuild, user logins will be restored to their status prior */
  /* to the rebuild.                                                                    */
  select system_stat_value
    into UserLoginStatus
    from system_status
   where system_stat_code = 'LOGINS_ALLOWED';

  UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = 'N' WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
  COMMIT;

	DELETE wl_del;

	INSERT INTO	wl_del(wl_key, po_nbr, bo_nbr, style_master_sku, color_nbr, receiving_id, shape_type, vendor_pack_id)
		 SELECT	wl_key, po_nbr, bo_nbr, style_master_sku, color_nbr, receiving_id, shape_type, vendor_pack_id
		   FROM	worklist
		  WHERE	status_code <> const_released;
	COMMIT;

	--
	-- To determine the shape type, decode statement is used
	-- If no decode matches, it is assumed to be at the style level and 1 is returned
	--
	DELETE	/*+ RULE */
	  FROM	wl_del
	 WHERE	(po_nbr, bo_nbr, style_master_sku, NVL(color_nbr, 0), NVL(receiving_id,0), NVL(vendor_pack_id,'NOPACK'),  shape_type)
	 	IN (SELECT NVL (po_dst_number, 0),
	 		   NVL (bo_number, 0),
			   NVL (style_master_sku, 0),
			   NVL (color_number, 0),
         NVL (receiver_number,0),
         NVL (vendor_pack, 'NOPACK'),
			   DECODE (NVL (aalrwk.dimension_number,'isnull'), 'isnull',
			   	DECODE (NVL (aalrwk.size_number, 'isnull'), 'isnull',
			   		DECODE (NVL (aalrwk.color_number, 'isnull'), 'isnull', 4
			   		,3)
			   	,2)
			   ,1)


		      FROM aalrwk);
	COMMIT;

	-- Delete all occurances of the wl_keys in wl_del from the worklist and all shape tables.
	-- If this fails, will log an error and return false. May want to handle this....
  PrepareForWorkListDelete();
	v_bSuccess	:= 	AllocMMS.DeleteWLKeys(' IN (SELECT wl_key FROM wl_del)');

	/* Clean up of "q" table */
	DELETE aalwrkq;

	COMMIT;

	-- clean format table except for approved/unapproved Auto-Allocation results
	DELETE actual_format where alloc_nbr not in
		(select alloc_nbr from worklist
		where aa_job_nbr is not null
			and status_code IN (const_approved, const_unapproved));
	COMMIT;

	-- This gets rid of released worklist items along with their results
	-- no attempt is made to keep CAQ in synch, as it is rebuilt below
	proc_clean_results;

	-- This removes OBS trouble codes from the WorkList, as the overstated On Order By Store
	-- will have been removed because of the nightly sales update (aalapr), which happens
	-- semi-concurrently with this nightly WorkList rebuild.
	UPDATE worklist
	SET trouble_code = null
	WHERE trouble_code = 'OBS'
	AND status_code <> const_released;

	COMMIT;

	-- Now remove details for any WorkList line in a status of availalble. This allows passive
	-- line item deletes to remove individual details from WorkList keys. Note that this is
	-- primarily used by reserve stock details, as the rebuild only sends reserve stock info
	-- for non-zero items, which could change daily.
	-- Technically, passive line-item deletes should make approved / unapproved allocations
	-- into a discrepancy status; however, we're not doing that here.
	-- The risk of not flagging allocations where a passive line item delete changes the available
	-- is low, especially when combined with the fact that MMS will simply throw out results for an
	-- item that doesn't exist anymore.
	-- There's also little reason for reserve stock allocations to sit in an approved status overnight,
	-- and that's where the passive line-item deletes are most likely to happen.

	DELETE from pack_style
	WHERE  wl_key in
		(SELECT wl_key
		 FROM   worklist
		 WHERE  status_code = 10 AND shape_type = 4);

	DELETE from pack_color
	WHERE  wl_key in
		(SELECT wl_key
		 FROM   worklist
		 WHERE  status_code = 10 AND shape_type = 3);

	DELETE from pack_size
	WHERE  wl_key in
		(SELECT wl_key
		 FROM   worklist
		 WHERE  status_code = 10 AND shape_type = 2);

	DELETE from pack_dimension
	WHERE  wl_key in
		(SELECT wl_key
		 FROM   worklist
		 WHERE  status_code = 10 AND shape_type = 1);


	-- now rebult CAQ based on remaining allocations
	alloccaq.rebuildcaqhost;
	COMMIT;

  /* The first two phases of the rebuild are complete.  Restore user login status for now, */
  /* although they will again be disabled for the final stage.                             */
  UPDATE SYSTEM_STATUS SET SYSTEM_STAT_VALUE = UserLoginStatus WHERE SYSTEM_STAT_CODE = 'LOGINS_ALLOWED';
  COMMIT;


END proc_aalrwk;


PROCEDURE proc_aalloc(p_bCalledForRebuild	IN BOOLEAN) AS
	CURSOR cur_aalloc IS
		SELECT	*
		  FROM	aalloc;
BEGIN
	DELETE	locations
	 WHERE	location_id IN (SELECT	location_id
							  FROM	locations
							MINUS
							SELECT	location_number
							  FROM	aalloc);

	INSERT INTO	locations (location_id, avail_for_alloc)
		 SELECT	location_number,	'N'
		   FROM	aalloc
		  WHERE	location_number IN (SELECT	location_number
									  FROM	aalloc
									MINUS
									SELECT	location_id
									  FROM	locations);

	FOR aalloc_rec IN cur_aalloc LOOP
	  UPDATE locations aa
		SET location_name = aalloc_rec.location_name,
		    warehouse_flag = aalloc_rec.whse_flag,
		    city		= aalloc_rec.location_city,
		    state		= aalloc_rec.location_state,
		    region_nbr	= aalloc_rec.location_region,
		    region_name = aalloc_rec.region_name,
		    district_nbr	= aalloc_rec.location_district,
		    district_name = aalloc_rec.district_name,
		    date_opened	 = func_is_valid_date (aalloc_rec.open_date),
		    selling_sq_ft	 = aalloc_rec.retail_square_feet,
		    annual_sales = aalloc_rec.annual_sales,
		    z_open_01  = aalloc_rec.z_open_01,
		    z_open_02 = aalloc_rec.z_open_02,
		    z_open_03 = aalloc_rec.z_open_03,
		    z_open_04 = aalloc_rec.z_open_04,
		    z_open_05 = aalloc_rec.z_open_05,
		    z_open_06 = aalloc_rec.z_open_06,
		    z_open_07 = aalloc_rec.z_open_07,
		    z_open_08 = aalloc_rec.z_open_08,
		    z_open_09 = aalloc_rec.z_open_09,
		    z_open_10 = aalloc_rec.z_open_10,
		    z_open_11 = aalloc_rec.z_open_11,
		    z_open_12 = aalloc_rec.z_open_12,
		    z_open_13 = aalloc_rec.z_open_13,
		    z_open_14 = aalloc_rec.z_open_14,
		    z_open_15 = aalloc_rec.z_open_15,
		    z_open_16 = aalloc_rec.z_open_16,
		    z_open_17 = aalloc_rec.z_open_17,
		    z_open_18 = aalloc_rec.z_open_18,
		    z_open_19 = aalloc_rec.z_open_19,
		    z_open_20 = aalloc_rec.z_open_20,
		    z_open_21 = aalloc_rec.z_open_21,
		    z_open_22 = aalloc_rec.z_open_22,
		    z_open_23 = aalloc_rec.z_open_23,
		    z_open_24 = aalloc_rec.z_open_24,
		    z_open_25 = aalloc_rec.z_open_25,
		    z_open_26 = aalloc_rec.z_open_26,
		    z_open_27 = aalloc_rec.z_open_27,
		    z_open_28 = aalloc_rec.z_open_28,
		    z_open_29 = aalloc_rec.z_open_29,
		    z_open_30 = aalloc_rec.z_open_30,
		    z_open_31 = aalloc_rec.z_open_31,
		    z_open_32 = aalloc_rec.z_open_32,
		    z_open_33 = aalloc_rec.z_open_33,
		    z_open_34 = aalloc_rec.z_open_34,
		    z_open_35 = aalloc_rec.z_open_35,
		    z_open_36 = aalloc_rec.z_open_36,
		    z_open_37 = aalloc_rec.z_open_37,
		    z_open_38 = aalloc_rec.z_open_38,
		    z_open_39 = aalloc_rec.z_open_39,
		    z_open_40 = aalloc_rec.z_open_40
	     WHERE aa.location_id	= aalloc_rec.location_number;
	END LOOP;
END proc_aalloc;


PROCEDURE proc_aalcal(p_bCalledForRebuild	IN BOOLEAN) AS
	CURSOR cur_cal IS
		SELECT	year, week
		  FROM	aalcal
		ORDER BY year, week;

	cal_order	calendar.week_order%TYPE	:= 1;
BEGIN
	DELETE calendar;

	FOR cur_rec IN cur_cal LOOP
		INSERT INTO	calendar(year, week, week_order)
			 VALUES	(cur_rec.year, cur_rec.week, cal_order);

		cal_order	:= cal_order + 1;
	END LOOP;
END proc_aalcal;


PROCEDURE proc_aalcaw(p_bCalledForRebuild	IN BOOLEAN) AS
	week_count	PLS_INTEGER;
	cur_week	calendar.week_order%TYPE;
BEGIN

	SELECT	COUNT(*)
	  INTO	week_count
	  FROM	current_week;

	IF week_count > 0 THEN
		-- Call the specific roll for weekly stage_dimension roll.
		-- Then add 1 to current_week and set calendar to next week.

		proc_do_roll;

		SELECT	week_order
		  INTO	cur_week
		  FROM	calendar
		 WHERE	current_week	= 'Y';

		UPDATE	calendar
		   SET	current_week	= 'N'
		 WHERE	week_order		= cur_week;

		UPDATE	calendar
		   SET	current_week	= 'Y'
		 WHERE	week_order		= cur_week + 1;

		UPDATE	current_week
		   SET	(year, week)	= (SELECT	year, week
									 FROM	calendar
									WHERE	current_week	= 'Y');

		COMMIT;
	ELSE
		INSERT INTO	current_week(year, week)
			 SELECT	year, week
			   FROM	aalcaw;

		UPDATE	calendar
		   SET	current_week	= 'N';

		UPDATE	calendar
		   SET	current_week	= 'Y'
		 WHERE	(year, week) IN (SELECT	year, week
								   FROM	current_week);

		COMMIT;
	END IF;
END proc_aalcaw;


PROCEDURE proc_aalnot(p_bCalledForRebuild	IN BOOLEAN) AS
	CURSOR cur_addupd IS
		SELECT	po_dst_number po_nbr,
				NVL(bo_number, 0) bo_nbr,
				NVL(note_sequence, 0) seq_nbr,
				po_note po_info
		  FROM	aalnot
		 WHERE	operation_code IN ('1', '2');

	CURSOR cur_del IS
		SELECT	po_dst_number po_nbr,
				NVL(bo_number, 0) bo_nbr,
				NVL(note_sequence, 0) seq_nbr
		  FROM	aalnot
		 WHERE	operation_code = '3';

	key_count	NUMBER(4);			-- limit 999
BEGIN
	FOR curr_rec_del IN cur_del LOOP
		DELETE	detail_po pod
		 WHERE	pod.po_nbr			= curr_rec_del.po_nbr
		   AND	pod.bo_nbr			= curr_rec_del.bo_nbr
		   AND	pod.line_sequence	= curr_rec_del.seq_nbr;
	END LOOP;

	FOR curr_rec IN cur_addupd LOOP
		SELECT	COUNT(*)
		  INTO	key_count
		  FROM	detail_po pod
		 WHERE	pod.po_nbr			= curr_rec.po_nbr
		   AND	pod.bo_nbr			= curr_rec.bo_nbr
		   AND	pod.line_sequence	= curr_rec.seq_nbr;

		IF key_count < 1 THEN
			INSERT INTO detail_po(po_nbr, bo_nbr, line_sequence, po_info)
				 VALUES (curr_rec.po_nbr,
						 curr_rec.bo_nbr,
						 curr_rec.seq_nbr,
						 curr_rec.po_info);
		ELSE
			UPDATE	detail_po pod
			   SET	pod.po_info			= curr_rec.po_info
			 WHERE	pod.po_nbr			= curr_rec.po_nbr
			   AND	pod.bo_nbr			= curr_rec.bo_nbr
			   AND	pod.line_sequence	= curr_rec.seq_nbr;
		END IF;
	END LOOP;
END proc_aalnot;


-- This routine is called during idle time in the Unix daemon processing
-- incoming files.  This routine will delete the contents of temp tables
-- and call the stored procedures associated with the table update to
-- cause the queues to be services.  Technically the the table deletion
-- shouldn't be required at this point, but it is left in as a defensive
-- measure.
PROCEDURE proc_shapeq AS
	q_row_count   PLS_INTEGER;
BEGIN
	-- The Worklist
	SELECT	COUNT(*)
	  INTO	q_row_count
	  FROM	aalwrkq
	 WHERE	ROWNUM < 2;

	IF q_row_count > 0 THEN
		DELETE aalwrk;
		allocmms.proc_aalwrk(false);
	END IF;
END proc_shapeq;


/* Following procedure proc_do_roll has been modified by Abhi Sharma(JDA Software):
   - Added attribute columns ATTR_1_CODE through ATTR_12_CODE to enable attribute
     based Data Collect as per the CR changes
*/
--
-- This procedure performs the history roll of the STAGE_DIMENSION
-- table and recreates the STAGE_SUBCLASS table.
--
PROCEDURE proc_do_roll AS
  -- Table space name
  stageDimensionTablespaceName user_tables.tablespace_name%TYPE;

  -- Saved DDL to recreate indexes for the STAGE_DIMENSION table.
  ddlForStage_Dimension DDL_tabType;

  -- Extent information for the STAGE_DIMENSION table.
--  stageDimensionInitialExtent PLS_INTEGER;
--  stageDimensionNextExtent PLS_INTEGER;
--  stageDimensionMinExtent PLS_INTEGER;
--  stageDimensionMaxExtent PLS_INTEGER;
--  stageDimensionPctIncrease PLS_INTEGER;

-- Extent information for the STAGE_DIMENSION table.
  stageDimensionInitialExtent user_tables.initial_extent%TYPE;
  stageDimensionNextExtent    user_tables.next_extent%TYPE;
  stageDimensionMinExtent    user_tables.min_extents%TYPE;
  stageDimensionMaxExtent     user_tables.max_extents%TYPE;
  stageDimensionPctIncrease   user_tables.pct_increase%TYPE;
  StageDimensionIOTType       user_tables.iot_type%TYPE;

  strstageDimensionNextExtent VARCHAR2(30);
  strstageDimensionPctIncrease VARCHAR2(30);

BEGIN
  -- Get the tablespace of the STAGE_DIMENSION table.
  stageDimensionTablespaceName := GetTableSpaceName('STAGE_DIMENSION');

  -- Check for a good tablespace name
  IF stageDimensionTablespaceName IS NULL THEN
    LogError('', 'proc_do_roll : Unable to determine the tablespace name for the stage_dimension table');
    RETURN;
  END IF;

  -- Get the extent information for the STAGE_DIMENSION table.
  IF NOT Getextentinfo( 'STAGE_DIMENSION', stageDimensionInitialExtent, stageDimensionNextExtent, stageDimensionMinExtent, stageDimensionMaxExtent, stageDimensionPctIncrease ) THEN
    LogError('', 'proc_do_roll : Unable to determine the table extents for the stage_dimension table');
    RETURN;
  END IF;

  -- Omit NEXT if Next_Extent is not explicitly specified
  IF stageDimensionNextExtent IS NULL THEN
    strstageDimensionNextExtent := '';
  ELSE
    strstageDimensionNextExtent := ' NEXT ' || stageDimensionNextExtent;
  END IF;

  -- Omit PCTINCREASE if it is not explicitly specified
  IF stageDimensionPctIncrease IS NULL THEN
    strstageDimensionPctIncrease := '';
  ELSE
    strstageDimensionPctIncrease := ' PCTINCREASE ' || stageDimensionPctIncrease;
  END IF;

  -- Grab the DDL for the indexes, etc. before we rename,
  ddlForStage_Dimension := AllocMMS.GetTableIndexAndKeyDDL('STAGE_DIMENSION');

  -- Rename the old table as a backup before the roll
  EXECUTE IMMEDIATE 'rename STAGE_DIMENSION to ' || OLD_STAGE_DIMENSION_TABLE_NAME;

  -- The purpose of the "where" clause is to clean the stage_dimension table of rows
  -- of all zeros.  All zeros means that the product has bee inactive for a long time
  -- and likely needs to be removed from the history information.
  EXECUTE IMMEDIATE
    'CREATE TABLE ' ||
    'STAGE_DIMENSION ' ||
    'NOLOGGING ' ||
    'TABLESPACE	' ||
    stageDimensionTablespaceName ||
    ' STORAGE (' ||
    ' INITIAL ' || stageDimensionInitialExtent ||
    strstageDimensionNextExtent ||
    ' MINEXTENTS ' || stageDimensionMinExtent ||
    ' MAXEXTENTS ' || stageDimensionMaxExtent ||
    strstageDimensionPctIncrease || ') ' ||
    'AS ' ||
  'SELECT /*+FULL(OLD$STAGE_DIMENSION) PARALLEL(OLD$STAGE_DIMENSION) */' ||
  --' SELECT *' ||
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
  '      ,0 AS WTD_SALES ' ||
  '      ,ON_HAND_CURR ' ||
  '      ,ON_HAND_CURR AS ON_HAND_01AGO' ||
  '      ,ON_HAND_01AGO AS ON_HAND_02AGO' ||
  '      ,ON_HAND_02AGO AS ON_HAND_03AGO' ||
  '      ,ON_HAND_03AGO AS ON_HAND_04AGO' ||
  '      ,ON_HAND_04AGO AS ON_HAND_05AGO' ||
  '      ,ON_HAND_05AGO AS ON_HAND_06AGO' ||
  '      ,ON_HAND_06AGO AS ON_HAND_07AGO' ||
  '      ,ON_HAND_07AGO AS ON_HAND_08AGO' ||
  '      ,ON_HAND_08AGO AS ON_HAND_09AGO' ||
  '      ,ON_HAND_09AGO AS ON_HAND_10AGO' ||
  '      ,ON_HAND_10AGO AS ON_HAND_11AGO' ||
  '      ,ON_HAND_11AGO AS ON_HAND_12AGO' ||
  '      ,ON_HAND_12AGO AS ON_HAND_13AGO' ||
  '      ,ON_HAND_13AGO AS ON_HAND_14AGO' ||
  '      ,ON_HAND_14AGO AS ON_HAND_15AGO' ||
  '      ,ON_HAND_15AGO AS ON_HAND_16AGO' ||
  '      ,ON_HAND_16AGO AS ON_HAND_17AGO' ||
  '      ,ON_HAND_17AGO AS ON_HAND_18AGO' ||
  '      ,ON_HAND_18AGO AS ON_HAND_19AGO' ||
  '      ,ON_HAND_19AGO AS ON_HAND_20AGO' ||
  '      ,ON_HAND_20AGO AS ON_HAND_21AGO' ||
  '      ,ON_HAND_21AGO AS ON_HAND_22AGO' ||
  '      ,ON_HAND_22AGO AS ON_HAND_23AGO' ||
  '      ,ON_HAND_23AGO AS ON_HAND_24AGO' ||
  '      ,ON_HAND_24AGO AS ON_HAND_25AGO' ||
  '      ,ON_HAND_25AGO AS ON_HAND_26AGO' ||
  '      ,ON_HAND_26AGO AS ON_HAND_27AGO' ||
  '      ,ON_HAND_27AGO AS ON_HAND_28AGO' ||
  '      ,ON_HAND_28AGO AS ON_HAND_29AGO' ||
  '      ,ON_HAND_29AGO AS ON_HAND_30AGO' ||
  '      ,ON_HAND_30AGO AS ON_HAND_31AGO' ||
  '      ,ON_HAND_31AGO AS ON_HAND_32AGO' ||
  '      ,ON_HAND_32AGO AS ON_HAND_33AGO' ||
  '      ,ON_HAND_33AGO AS ON_HAND_34AGO' ||
  '      ,ON_HAND_34AGO AS ON_HAND_35AGO' ||
  '      ,ON_HAND_35AGO AS ON_HAND_36AGO' ||
  '      ,ON_HAND_36AGO AS ON_HAND_37AGO' ||
  '      ,ON_HAND_37AGO AS ON_HAND_38AGO' ||
  '      ,ON_HAND_38AGO AS ON_HAND_39AGO' ||
  '      ,ON_HAND_39AGO AS ON_HAND_40AGO' ||
  '      ,ON_HAND_40AGO AS ON_HAND_41AGO' ||
  '      ,ON_HAND_41AGO AS ON_HAND_42AGO' ||
  '      ,ON_HAND_42AGO AS ON_HAND_43AGO' ||
  '      ,ON_HAND_43AGO AS ON_HAND_44AGO' ||
  '      ,ON_HAND_44AGO AS ON_HAND_45AGO' ||
  '      ,ON_HAND_45AGO AS ON_HAND_46AGO' ||
  '      ,ON_HAND_46AGO AS ON_HAND_47AGO' ||
  '      ,ON_HAND_47AGO AS ON_HAND_48AGO' ||
  '      ,ON_HAND_48AGO AS ON_HAND_49AGO' ||
  '      ,ON_HAND_49AGO AS ON_HAND_50AGO' ||
  '      ,ON_HAND_50AGO AS ON_HAND_51AGO' ||
  '      ,ON_HAND_51AGO AS ON_HAND_52AGO' ||
  '      ,ON_HAND_52AGO AS ON_HAND_53AGO' ||
  '      ,ON_HAND_53AGO AS ON_HAND_54AGO' ||
  '      ,ON_HAND_54AGO AS ON_HAND_55AGO' ||
  '      ,ON_HAND_55AGO AS ON_HAND_56AGO' ||
  '      ,ON_HAND_56AGO AS ON_HAND_57AGO' ||
  '      ,ON_HAND_57AGO AS ON_HAND_58AGO' ||
  '      ,ON_HAND_58AGO AS ON_HAND_59AGO' ||
  '      ,ON_HAND_59AGO AS ON_HAND_60AGO' ||
  '      ,ON_HAND_60AGO AS ON_HAND_61AGO' ||
  '      ,ON_HAND_61AGO AS ON_HAND_62AGO' ||
  '      ,ON_HAND_62AGO AS ON_HAND_63AGO' ||
  '      ,ON_HAND_63AGO AS ON_HAND_64AGO' ||
  '      ,ON_HAND_64AGO AS ON_HAND_65AGO' ||
  '      ,ON_HAND_65AGO AS ON_HAND_66AGO' ||
  '      ,ON_HAND_66AGO AS ON_HAND_67AGO' ||
  '      ,ON_HAND_67AGO AS ON_HAND_68AGO' ||
  '      ,ON_HAND_68AGO AS ON_HAND_69AGO' ||
  '      ,ON_HAND_69AGO AS ON_HAND_70AGO' ||
  '      ,ON_HAND_70AGO AS ON_HAND_71AGO' ||
  '      ,ON_HAND_71AGO AS ON_HAND_72AGO' ||
  '      ,ON_HAND_72AGO AS ON_HAND_73AGO' ||
  '      ,ON_HAND_73AGO AS ON_HAND_74AGO' ||
  '      ,ON_HAND_74AGO AS ON_HAND_75AGO' ||
  '      ,ON_HAND_75AGO AS ON_HAND_76AGO' ||
  '      ,ON_HAND_76AGO AS ON_HAND_77AGO' ||
  '      ,ON_HAND_77AGO AS ON_HAND_78AGO' ||
  '      ,WTD_SALES AS SLS_01AGO ' ||
  '      ,SLS_01AGO AS SLS_02AGO' ||
  '      ,SLS_02AGO AS SLS_03AGO' ||
  '      ,SLS_03AGO AS SLS_04AGO' ||
  '      ,SLS_04AGO AS SLS_05AGO' ||
  '      ,SLS_05AGO AS SLS_06AGO' ||
  '      ,SLS_06AGO AS SLS_07AGO' ||
  '      ,SLS_07AGO AS SLS_08AGO' ||
  '      ,SLS_08AGO AS SLS_09AGO' ||
  '      ,SLS_09AGO AS SLS_10AGO' ||
  '      ,SLS_10AGO AS SLS_11AGO' ||
  '      ,SLS_11AGO AS SLS_12AGO' ||
  '      ,SLS_12AGO AS SLS_13AGO' ||
  '      ,SLS_13AGO AS SLS_14AGO' ||
  '      ,SLS_14AGO AS SLS_15AGO' ||
  '      ,SLS_15AGO AS SLS_16AGO' ||
  '      ,SLS_16AGO AS SLS_17AGO' ||
  '      ,SLS_17AGO AS SLS_18AGO' ||
  '      ,SLS_18AGO AS SLS_19AGO' ||
  '      ,SLS_19AGO AS SLS_20AGO' ||
  '      ,SLS_20AGO AS SLS_21AGO' ||
  '      ,SLS_21AGO AS SLS_22AGO' ||
  '      ,SLS_22AGO AS SLS_23AGO' ||
  '      ,SLS_23AGO AS SLS_24AGO' ||
  '      ,SLS_24AGO AS SLS_25AGO' ||
  '      ,SLS_25AGO AS SLS_26AGO' ||
  '      ,SLS_26AGO AS SLS_27AGO' ||
  '      ,SLS_27AGO AS SLS_28AGO' ||
  '      ,SLS_28AGO AS SLS_29AGO' ||
  '      ,SLS_29AGO AS SLS_30AGO' ||
  '      ,SLS_30AGO AS SLS_31AGO' ||
  '      ,SLS_31AGO AS SLS_32AGO' ||
  '      ,SLS_32AGO AS SLS_33AGO' ||
  '      ,SLS_33AGO AS SLS_34AGO' ||
  '      ,SLS_34AGO AS SLS_35AGO' ||
  '      ,SLS_35AGO AS SLS_36AGO' ||
  '      ,SLS_36AGO AS SLS_37AGO' ||
  '      ,SLS_37AGO AS SLS_38AGO' ||
  '      ,SLS_38AGO AS SLS_39AGO' ||
  '      ,SLS_39AGO AS SLS_40AGO' ||
  '      ,SLS_40AGO AS SLS_41AGO' ||
  '      ,SLS_41AGO AS SLS_42AGO' ||
  '      ,SLS_42AGO AS SLS_43AGO' ||
  '      ,SLS_43AGO AS SLS_44AGO' ||
  '      ,SLS_44AGO AS SLS_45AGO' ||
  '      ,SLS_45AGO AS SLS_46AGO' ||
  '      ,SLS_46AGO AS SLS_47AGO' ||
  '      ,SLS_47AGO AS SLS_48AGO' ||
  '      ,SLS_48AGO AS SLS_49AGO' ||
  '      ,SLS_49AGO AS SLS_50AGO' ||
  '      ,SLS_50AGO AS SLS_51AGO' ||
  '      ,SLS_51AGO AS SLS_52AGO' ||
  '      ,SLS_52AGO AS SLS_53AGO' ||
  '      ,SLS_53AGO AS SLS_54AGO' ||
  '      ,SLS_54AGO AS SLS_55AGO' ||
  '      ,SLS_55AGO AS SLS_56AGO' ||
  '      ,SLS_56AGO AS SLS_57AGO' ||
  '      ,SLS_57AGO AS SLS_58AGO' ||
  '      ,SLS_58AGO AS SLS_59AGO' ||
  '      ,SLS_59AGO AS SLS_60AGO' ||
  '      ,SLS_60AGO AS SLS_61AGO' ||
  '      ,SLS_61AGO AS SLS_62AGO' ||
  '      ,SLS_62AGO AS SLS_63AGO' ||
  '      ,SLS_63AGO AS SLS_64AGO' ||
  '      ,SLS_64AGO AS SLS_65AGO' ||
  '      ,SLS_65AGO AS SLS_66AGO' ||
  '      ,SLS_66AGO AS SLS_67AGO' ||
  '      ,SLS_67AGO AS SLS_68AGO' ||
  '      ,SLS_68AGO AS SLS_69AGO' ||
  '      ,SLS_69AGO AS SLS_70AGO' ||
  '      ,SLS_70AGO AS SLS_71AGO' ||
  '      ,SLS_71AGO AS SLS_72AGO' ||
  '      ,SLS_72AGO AS SLS_73AGO' ||
  '      ,SLS_73AGO AS SLS_74AGO' ||
  '      ,SLS_74AGO AS SLS_75AGO' ||
  '      ,SLS_75AGO AS SLS_76AGO' ||
  '      ,SLS_76AGO AS SLS_77AGO' ||
  '      ,SLS_77AGO AS SLS_78AGO' ||
  '      ,SYSDATE AS LASTROLL ' ||
  '      ,ATTR_1_CODE ' ||
  '      ,ATTR_2_CODE ' ||
  '      ,ATTR_3_CODE ' ||
  '      ,ATTR_4_CODE ' ||
  '      ,ATTR_5_CODE ' ||
  '      ,ATTR_6_CODE ' ||
  '      ,ATTR_7_CODE ' ||
  '      ,ATTR_8_CODE ' ||
  '      ,ATTR_9_CODE ' ||
  '      ,ATTR_10_CODE ' ||
  '      ,ATTR_11_CODE ' ||
  '      ,ATTR_12_CODE ' ||
  '      ,0 AS REG_SLS_WTD ' ||
  '      ,REG_SLS_WTD   AS REG_SLS_01AGO  ' ||
  '      ,REG_SLS_01AGO AS REG_SLS_02AGO  ' ||
  '      ,REG_SLS_02AGO AS REG_SLS_03AGO  ' ||
  '      ,REG_SLS_03AGO AS REG_SLS_04AGO  ' ||
  '      ,REG_SLS_04AGO AS REG_SLS_05AGO  ' ||
  '      ,REG_SLS_05AGO AS REG_SLS_06AGO  ' ||
  '      ,REG_SLS_06AGO AS REG_SLS_07AGO  ' ||
  '      ,REG_SLS_07AGO AS REG_SLS_08AGO  ' ||
  '      ,REG_SLS_08AGO AS REG_SLS_09AGO  ' ||
  '      ,REG_SLS_09AGO AS REG_SLS_10AGO  ' ||
  '      ,REG_SLS_10AGO AS REG_SLS_11AGO  ' ||
  '      ,REG_SLS_11AGO AS REG_SLS_12AGO  ' ||
  '      ,REG_SLS_12AGO AS REG_SLS_13AGO  ' ||
  '      ,REG_SLS_13AGO AS REG_SLS_14AGO  ' ||
  '      ,REG_SLS_14AGO AS REG_SLS_15AGO  ' ||
  '      ,REG_SLS_15AGO AS REG_SLS_16AGO  ' ||
  '      ,REG_SLS_16AGO AS REG_SLS_17AGO  ' ||
  '      ,REG_SLS_17AGO AS REG_SLS_18AGO  ' ||
  '      ,REG_SLS_18AGO AS REG_SLS_19AGO  ' ||
  '      ,REG_SLS_19AGO AS REG_SLS_20AGO  ' ||
  '      ,REG_SLS_20AGO AS REG_SLS_21AGO  ' ||
  '      ,REG_SLS_21AGO AS REG_SLS_22AGO  ' ||
  '      ,REG_SLS_22AGO AS REG_SLS_23AGO  ' ||
  '      ,REG_SLS_23AGO AS REG_SLS_24AGO  ' ||
  '      ,REG_SLS_24AGO AS REG_SLS_25AGO  ' ||
  '      ,REG_SLS_25AGO AS REG_SLS_26AGO  ' ||
  '      ,REG_SLS_26AGO AS REG_SLS_27AGO  ' ||
  '      ,REG_SLS_27AGO AS REG_SLS_28AGO  ' ||
  '      ,REG_SLS_28AGO AS REG_SLS_29AGO  ' ||
  '      ,REG_SLS_29AGO AS REG_SLS_30AGO  ' ||
  '      ,REG_SLS_30AGO AS REG_SLS_31AGO  ' ||
  '      ,REG_SLS_31AGO AS REG_SLS_32AGO  ' ||
  '      ,REG_SLS_32AGO AS REG_SLS_33AGO  ' ||
  '      ,REG_SLS_33AGO AS REG_SLS_34AGO  ' ||
  '      ,REG_SLS_34AGO AS REG_SLS_35AGO  ' ||
  '      ,REG_SLS_35AGO AS REG_SLS_36AGO  ' ||
  '      ,REG_SLS_36AGO AS REG_SLS_37AGO  ' ||
  '      ,REG_SLS_37AGO AS REG_SLS_38AGO  ' ||
  '      ,REG_SLS_38AGO AS REG_SLS_39AGO  ' ||
  '      ,REG_SLS_39AGO AS REG_SLS_40AGO  ' ||
  '      ,REG_SLS_40AGO AS REG_SLS_41AGO  ' ||
  '      ,REG_SLS_41AGO AS REG_SLS_42AGO  ' ||
  '      ,REG_SLS_42AGO AS REG_SLS_43AGO  ' ||
  '      ,REG_SLS_43AGO AS REG_SLS_44AGO  ' ||
  '      ,REG_SLS_44AGO AS REG_SLS_45AGO  ' ||
  '      ,REG_SLS_45AGO AS REG_SLS_46AGO  ' ||
  '      ,REG_SLS_46AGO AS REG_SLS_47AGO  ' ||
  '      ,REG_SLS_47AGO AS REG_SLS_48AGO  ' ||
  '      ,REG_SLS_48AGO AS REG_SLS_49AGO  ' ||
  '      ,REG_SLS_49AGO AS REG_SLS_50AGO  ' ||
  '      ,REG_SLS_50AGO AS REG_SLS_51AGO  ' ||
  '      ,REG_SLS_51AGO AS REG_SLS_52AGO  ' ||
  '      ,REG_SLS_52AGO AS REG_SLS_53AGO  ' ||
  '      ,REG_SLS_53AGO AS REG_SLS_54AGO  ' ||
  '      ,REG_SLS_54AGO AS REG_SLS_55AGO  ' ||
  '      ,REG_SLS_55AGO AS REG_SLS_56AGO  ' ||
  '      ,REG_SLS_56AGO AS REG_SLS_57AGO  ' ||
  '      ,REG_SLS_57AGO AS REG_SLS_58AGO  ' ||
  '      ,REG_SLS_58AGO AS REG_SLS_59AGO  ' ||
  '      ,REG_SLS_59AGO AS REG_SLS_60AGO  ' ||
  '      ,REG_SLS_60AGO AS REG_SLS_61AGO  ' ||
  '      ,REG_SLS_61AGO AS REG_SLS_62AGO  ' ||
  '      ,REG_SLS_62AGO AS REG_SLS_63AGO  ' ||
  '      ,REG_SLS_63AGO AS REG_SLS_64AGO  ' ||
  '      ,REG_SLS_64AGO AS REG_SLS_65AGO  ' ||
  '      ,REG_SLS_65AGO AS REG_SLS_66AGO  ' ||
  '      ,REG_SLS_66AGO AS REG_SLS_67AGO  ' ||
  '      ,REG_SLS_67AGO AS REG_SLS_68AGO  ' ||
  '      ,REG_SLS_68AGO AS REG_SLS_69AGO  ' ||
  '      ,REG_SLS_69AGO AS REG_SLS_70AGO  ' ||
  '      ,REG_SLS_70AGO AS REG_SLS_71AGO  ' ||
  '      ,REG_SLS_71AGO AS REG_SLS_72AGO  ' ||
  '      ,REG_SLS_72AGO AS REG_SLS_73AGO  ' ||
  '      ,REG_SLS_73AGO AS REG_SLS_74AGO  ' ||
  '      ,REG_SLS_74AGO AS REG_SLS_75AGO  ' ||
  '      ,REG_SLS_75AGO AS REG_SLS_76AGO  ' ||
  '      ,REG_SLS_76AGO AS REG_SLS_77AGO  ' ||
  '      ,REG_SLS_77AGO AS REG_SLS_78AGO  ' ||
  'FROM ' ||
    OLD_STAGE_DIMENSION_TABLE_NAME ||
  	' WHERE	NVL(on_hand_78ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_77ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_76ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_75ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_74ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_73ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_72ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_71ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_70ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_69ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_68ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_67ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_66ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_65ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_64ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_63ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_62ago, 0) <> 0 ' ||
      'OR    NVL(on_hand_61ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_60ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_59ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_58ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_57ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_56ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_55ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_54ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_53ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_52ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_51ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_50ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_49ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_48ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_47ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_46ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_45ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_44ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_43ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_42ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_41ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_40ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_39ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_38ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_37ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_36ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_35ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_34ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_33ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_32ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_31ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_30ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_29ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_28ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_27ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_26ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_25ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_24ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_23ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_22ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_21ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_20ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_19ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_18ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_17ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_16ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_15ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_14ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_13ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_12ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_11ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_10ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_09ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_08ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_07ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_06ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_05ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_04ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_03ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_02ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_01ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_78ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_77ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_76ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_75ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_74ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_73ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_72ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_71ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_70ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_69ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_68ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_67ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_66ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_65ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_64ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_63ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_62ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_61ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_60ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_59ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_58ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_57ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_56ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_55ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_54ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_53ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_52ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_51ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_50ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_49ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_48ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_47ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_46ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_45ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_44ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_43ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_42ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_41ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_40ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_39ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_38ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_37ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_36ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_35ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_34ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_33ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_32ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_31ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_30ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_29ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_28ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_27ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_26ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_25ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_24ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_23ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_22ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_21ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_20ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_19ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_18ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_17ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_16ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_15ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_14ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_13ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_12ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_11ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_10ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_09ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_08ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_07ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_06ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_05ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_04ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_03ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_02ago, 0) <> 0 ' ||
  	  'OR	 NVL(sls_01ago, 0) <> 0 ' ||
  	  'OR	 NVL(on_hand_curr, 0) <> 0 ' ||
  	  'OR	 NVL(dnf_intransit, 0) <> 0 ' ||
  	  'OR	 NVL(wtd_sales, 0) <> 0 ' ||
  	  'OR	 NVL(str_on_order, 0) <> 0'   ||
      'OR    NVL(reg_sls_78ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_77ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_76ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_75ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_74ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_73ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_72ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_71ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_70ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_69ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_68ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_67ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_66ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_65ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_64ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_63ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_62ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_61ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_60ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_59ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_58ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_57ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_56ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_55ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_54ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_53ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_52ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_51ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_50ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_49ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_48ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_47ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_46ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_45ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_44ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_43ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_42ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_41ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_40ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_39ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_38ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_37ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_36ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_35ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_34ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_33ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_32ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_31ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_30ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_29ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_28ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_27ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_26ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_25ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_24ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_23ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_22ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_21ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_20ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_19ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_18ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_17ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_16ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_15ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_14ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_13ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_12ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_11ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_10ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_09ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_08ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_07ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_06ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_05ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_04ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_03ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_02ago, 0) <> 0   ' ||
      'OR    NVL(reg_sls_01ago, 0) <> 0   ' ||
      'OR    NVL(REG_SLS_WTD, 0) <> 0' ;

  EXECUTE IMMEDIATE 'drop TABLE ' || OLD_STAGE_DIMENSION_TABLE_NAME;

  -- recreate the indexes for the stage_dimension table.
  BEGIN
    AllocMMS.ExecutedIndexAndKeyDDL(ddlForStage_Dimension);

  EXCEPTION
     WHEN OTHERS THEN
          LogError('', 'proc_do_roll : Unable to recreate index(es) for the STAGE_DIMENSION table.  Any indexes will have to be manually created.');
     RAISE;
  END;

  AllocMMS.RebuildStageSubclass;
  AllocMMS.RebuildStageClass;
  
EXCEPTION

  WHEN OTHERS THEN

  IF Tableexists(OLD_STAGE_DIMENSION_TABLE_NAME) THEN
    IF TableExists('STAGE_DIMENSION') THEN
       EXECUTE IMMEDIATE 'drop table STAGE_DIMENSION';
    END IF;
    EXECUTE IMMEDIATE 'rename ' || OLD_STAGE_DIMENSION_TABLE_NAME || ' to STAGE_DIMENSION';
  END IF;

  RAISE;  -- Reraise exception

END proc_do_roll;

--01/17/2013 Devshree Gupta - replaced old routine with the new changed routine
--Replaced old proc_aalrst with new routine for TABLE AALRST
--02/22/2005 GSM Added per Bob Nightingale for Sku Authorization process
-- This routine is called when data exists for table AALRST
PROCEDURE proc_aalrst(p_bcalledforrebuild IN boolean) IS
CURSOR cur_addupd IS
SELECT sku_number,
  location_number
FROM aalrst
WHERE operation_code IN('1',   '2')
ORDER BY 1,
  2;

CURSOR cur_delloc IS
SELECT sku_number,
  location_number
FROM aalrst
WHERE operation_code = '3'
 AND location_number IS NOT NULL
ORDER BY 1,
  2;

CURSOR cur_delsku IS
SELECT sku_number
FROM aalrst
WHERE operation_code = '3'
 AND location_number IS NULL
 AND sku_number IS NOT NULL;

CURSOR rst_views IS
SELECT view_name,
  view_id
FROM view_header
WHERE UPPER(SUBSTR(view_name,   1,   2)) BETWEEN 'X0'
 AND 'X9' FOR

UPDATE NOWAIT;

CURSOR get_tokens(vid NUMBER) IS
SELECT view_token
FROM view_detail_filter_tb
WHERE view_id = vid
ORDER BY view_line_nbr;

key_count pls_integer;
local_view_name view_header.view_name%TYPE;
local_view_id view_header.view_id%TYPE;
last_sku pls_integer;
const_max_token_len constant pls_integer := 48;

--DEVSHREE adding a key increment counter
key_increment_ctr rst_cond_header.rst_cond_key%TYPE;

FUNCTION local_next_view_id RETURN view_header.view_id%TYPE IS llv_next_id view_header.view_id%TYPE;
llv_parm_id view_header.view_id%TYPE;
pragma autonomous_transaction;
BEGIN
  SELECT parameter_value
  INTO llv_parm_id
  FROM aam_parameters
  WHERE parameter_type = 'COUNTER'
   AND parameter_code = 'NEXT_VIEW_HEADER_ID' FOR

  UPDATE;

  SELECT MAX(view_id) + 1
  INTO llv_next_id
  FROM view_header
  WHERE view_id >= 1000000;

  IF llv_parm_id > llv_next_id THEN
    llv_next_id := llv_parm_id;
  END IF;

  --DEVSHREE increment the value of AAM_PARAMETERS counter by 1

  UPDATE aam_parameters
  SET parameter_value = parameter_value + 1
  WHERE parameter_type = 'COUNTER'
   AND parameter_code = 'NEXT_VIEW_HEADER_ID';

  COMMIT;

  RETURN llv_next_id;

EXCEPTION
WHEN others THEN
  ROLLBACK;
  Logerror ( 'AAM_PARAMETERS'
           , 'proc_aalrst: local_next_view_id - ' || sqlerrm
         , sqlcode );
  RAISE;
END local_next_view_id;

--*******************************************************************************************************************************
--Procedure  local_proc_write_tokens
--*******************************************************************************************************************************

PROCEDURE local_proc_write_tokens AS
local_token VARCHAR2(100);
test_token VARCHAR2(100);
CURSOR gttloc IS
SELECT nbr
FROM gttnbr
ORDER BY nbr;
first_token boolean;
line_ctr pls_integer;
BEGIN
  SELECT COUNT(nbr)
  INTO line_ctr
  FROM gttnbr
  WHERE rownum < 2;

  IF line_ctr <> 1 THEN
    RETURN;
  END IF;

  -- line_ctr := 1;

  DELETE FROM view_detail_filter_tb
  WHERE view_id = local_view_id;
  local_token := 'LOCATION_ID IN (';
  first_token := TRUE;
  FOR cur_loc IN gttloc
  LOOP

    IF first_token THEN
      test_token := local_token || to_char(cur_loc.nbr);
    ELSE
      test_token := local_token || ',' || to_char(cur_loc.nbr);
    END IF;

    first_token := FALSE;

    IF LENGTH(test_token) > const_max_token_len THEN
      INSERT
      INTO view_detail_filter_tb(view_id,   view_line_nbr,   view_token,   saved_with_names)
      VALUES(local_view_id,   line_ctr,   local_token,   'Y');
      local_token := ',' || to_char(cur_loc.nbr);
      line_ctr := line_ctr + 1;
    ELSE
      local_token := test_token;
    END IF;

  END LOOP;

  local_token := local_token || ')';
  INSERT
  INTO view_detail_filter_tb(view_id,   view_line_nbr,   view_token,   saved_with_names)
  VALUES(local_view_id,   line_ctr,   local_token,   'Y');

  UPDATE aam_parameters
  SET parameter_value = parameter_value + 1
  WHERE parameter_type = 'LOCATION_RESTRICTIONS'
   AND parameter_code = 'LOCRST_VERSION';
  COMMIT;
  local_token := '';
END local_proc_write_tokens;

--*******************************************************************************************************************************
--Procedure  local_proc_read_tokens
--*******************************************************************************************************************************
PROCEDURE local_proc_read_tokens AS
pos_leftparen pls_integer;
pos_rightparen pls_integer;
pos_lastcomma pls_integer;
pos_nextcomma pls_integer;
pos_current pls_integer;
last_token VARCHAR2(50);
this_token VARCHAR2(100);
local_loc NUMBER;
BEGIN
  BEGIN
    SELECT view_id
    INTO local_view_id
    FROM view_header
    WHERE view_name = local_view_name;

  EXCEPTION
  WHEN no_data_found THEN
    NULL;
  END;

  DELETE FROM gttnbr;
  last_token := '';
  FOR tok_rec IN get_tokens(local_view_id)
  LOOP
    this_token := last_token || tok_rec.view_token;
    last_token := tok_rec.view_token;
    pos_leftparen := instr(this_token,   '(');

    IF pos_leftparen = 0 THEN
      pos_leftparen := instr(this_token,   ',');
    END IF;

    pos_rightparen := instr(this_token,   ')');

    IF pos_rightparen = 0 THEN
      pos_rightparen := instr(this_token,   ',',   -1);
    END IF;

    pos_current := pos_leftparen;
    WHILE pos_current < pos_rightparen
    LOOP
      pos_lastcomma := pos_current;
      pos_current := instr(this_token,   ',',   pos_lastcomma + 1);

      IF pos_current = 0 THEN
        pos_current := pos_rightparen;
      END IF;

      local_loc := to_number(SUBSTR(this_token,   pos_lastcomma + 1,   pos_current -(pos_lastcomma + 1)));
      SELECT COUNT(nbr)
      INTO key_count
      FROM gttnbr
      WHERE nbr = local_loc;

      IF key_count = 0 THEN
        INSERT
        INTO gttnbr(nbr)
        VALUES(local_loc);
      END IF;

    END LOOP;

  END LOOP;

END local_proc_read_tokens;


BEGIN
  --***************************************************************************************************************************************
  --DELETE ALL RECORDS WITH OP CODE 3

  --*******************************************************************************************************************************
  -- DEVSHREE - if there is any record in AALRST with op code 3 and SKu_number = NULL then delete all the views and related records
  -- in the tables which have the first two letters of their names between X0 to X9
  SELECT COUNT(operation_code)
  INTO key_count
  FROM aalrst
  WHERE operation_code = '3'
   AND sku_number IS NULL;

  IF key_count > 0 THEN
    FOR del_rec IN rst_views
    LOOP
      --DEVSHREE - changed rst_cond_name to rst_cond_key. Previous code used rst_cond_name to find records for deletion.

      DELETE FROM rst_cond_detail
      WHERE rst_cond_key IN
        (SELECT rst_cond_key
         FROM rst_cond_header
         WHERE view_name = del_rec.view_name)
      ;

      DELETE FROM rst_cond_header
      WHERE view_name = del_rec.view_name;

      DELETE FROM view_detail_filter_tb
      WHERE view_id = del_rec.view_id;

      DELETE FROM view_header
      WHERE CURRENT OF rst_views;

    END LOOP;

    UPDATE aam_parameters
    SET parameter_value = parameter_value + 1
    WHERE parameter_type = 'LOCATION_RESTRICTIONS'
     AND parameter_code = 'LOCRST_VERSION';
    COMMIT;
  END IF;

  --*************************************************************************************************************************
  --
  FOR rec IN cur_delsku
  LOOP
    local_view_name := 'X' || to_char(rec.sku_number);

    --DEVSHREE - RST_COND_DETAIL does not contain rst_cond_name column anymore. Replaced rst_cond_name with rst_cond_key

    DELETE FROM rst_cond_detail
    WHERE rst_cond_key IN
      (SELECT rst_cond_key
       FROM rst_cond_header
       WHERE view_name = local_view_name)
    ;

    DELETE FROM rst_cond_header
    WHERE view_name = local_view_name;

    DELETE FROM view_detail_filter_tb
    WHERE view_id IN
      (SELECT view_id
       FROM view_header
       WHERE view_name = local_view_name)
    ;

    DELETE FROM view_header
    WHERE view_name = local_view_name;

    UPDATE aam_parameters
    SET parameter_value = parameter_value + 1
    WHERE parameter_type = 'LOCATION_RESTRICTIONS'
     AND parameter_code = 'LOCRST_VERSION';
    COMMIT;
  END LOOP;

  --***********************************************************************************************************************

  last_sku := 0;
  FOR rec IN cur_delloc -- deletes one location from a sku
  LOOP

    IF rec.sku_number <> last_sku THEN

      IF last_sku > 0 THEN
        local_proc_write_tokens;
      END IF;

      local_view_name := 'X' || to_char(rec.sku_number);
      local_proc_read_tokens;
      last_sku := rec.sku_number;

    END IF;

    DELETE FROM gttnbr
    WHERE nbr = rec.location_number;

    SELECT COUNT(*)
    INTO key_count
    FROM gttnbr
    WHERE rownum < 2;
    -- check if ANY rows exist in GTTNBR

    IF key_count = 0 THEN

      DELETE FROM rst_cond_header
      WHERE view_name = local_view_name;

      DELETE FROM view_detail_filter_tb
      WHERE view_id IN
        (SELECT view_id
         FROM view_header
         WHERE view_name = local_view_name)
      ;

      DELETE FROM view_header
      WHERE view_name = local_view_name;

      UPDATE aam_parameters
      SET parameter_value = parameter_value + 1
      WHERE parameter_type = 'LOCATION_RESTRICTIONS'
       AND parameter_code = 'LOCRST_VERSION';
      COMMIT;
    END IF;

  END LOOP;

  local_proc_write_tokens;

  --**************************************************************************************************************************
  --  ADD or UPDATE RECORDS
  --**************************************************************************************************************************
  last_sku := 0;
  FOR rec IN cur_addupd
  LOOP

    IF rec.sku_number <> last_sku THEN

      IF last_sku > 0 THEN
        -- Finish up the write to the detail table
        local_proc_write_tokens;
      END IF;

      local_view_name := 'X' || to_char(rec.sku_number);
      SELECT COUNT(view_name)
      INTO key_count
      FROM view_header
      WHERE view_name = local_view_name;

      IF key_count = 0 THEN

        /*-- New View
                                      SELECT MAX (view_id) + 1
                                      INTO local_view_id
                                      FROM VIEW_HEADER;*/

         local_view_id := local_next_view_id;

        IF local_view_id IS NULL THEN
          local_view_id := 1;
        END IF;

        INSERT
        INTO view_header(view_id,   view_name,   TABLE_NAME,   user_id,   global_flag,   technique_filter_flag,   aam_createuser)
        VALUES(local_view_id,   local_view_name,   'LOCATIONS',   'SYSTEM',   'Y',   'N',   'SYSTEM');

        --DEVSHREE increment the key value by one for the new record in RST_COND_HEADER and RST_COND_DETAIL
        --DEVSHREE also this new key should not be present in both the rst tables. This is just a check, although
        -- the possibility that this will happen is rare, since deletion of records takes care of this.
        --If there are no previous records in the table then the key is taken to be 1
        SELECT COUNT(rst_cond_key)
        INTO key_count
        FROM rst_cond_header;

        IF key_count = 0 THEN
          key_increment_ctr := 1;
        ELSE
          SELECT MAX(rst_cond_key) + 1
          INTO key_increment_ctr
          FROM rst_cond_header;
        END IF;

        INSERT
        INTO rst_cond_header(rst_cond_key,   rst_cond_name,   view_name,   view_id,   view_table_name,   view_user_id,   view_global_flag,   exclusive_flag,   createuser,   createdate,   updateuser,   updatedate)
        VALUES(key_increment_ctr,   local_view_name,   local_view_name,   local_view_id,   'LOCATIONS',   'SYSTEM',   'Y',   'N',   'SYSTEM',   sysdate,   'SYSTEM',   sysdate);

        INSERT
        INTO rst_cond_detail(rst_cond_key,   rst_cond_line_nbr,   dimension_nbr,   group_nbr,   hierarchy_nbr,   rst_cond_operand_code,   rst_cond_value,   createuser,   createdate,   updateuser,   updatedate)
--CEB FIX 2013-01-29
        --VALUES(key_increment_ctr,   1,   1,   1,   7,   '=',   rec.sku_number,   'SYSTEM',   sysdate,   'SYSTEM',   sysdate);
        VALUES(key_increment_ctr,   1,   1,   7,   1,   '=',   rec.sku_number,   'SYSTEM',   sysdate,   'SYSTEM',   sysdate);
--CEB FIX END
        INSERT
        INTO view_detail_filter_tb(view_id,   view_line_nbr,   saved_with_names,   view_token)
        VALUES(local_view_id,   1,   'Y',   'LOCATION_ID IN (' || to_char(rec.location_number) || ')');

        COMMIT;
      END IF;

      -- New View
      local_proc_read_tokens;
      last_sku := rec.sku_number;

    END IF;

    SELECT COUNT(nbr)
    INTO key_count
    FROM gttnbr
    WHERE nbr = rec.location_number;

    IF key_count = 0 THEN
      INSERT
      INTO gttnbr(nbr)
      VALUES(rec.location_number);
    END IF;

  END LOOP;

  local_proc_write_tokens;
END proc_aalrst;

PROCEDURE proc_clean_results AS
	local_allocnbr	NUMBER(10):= NULL;
	min_wlkey		NUMBER(10);
	v_bSuccess		BOOLEAN;
BEGIN
	-- Use the results and worklist purge process that is included with AAL and configured via Allocation Administration
	AALResultsUtils.PurgeResults;


	/************************************************************************
	* These next steps are a cleanup of records that shouldn't exist anyway *
	*************************************************************************/

	-- Results Header and Detail based on lowest available worklist
	BEGIN
		SELECT	MIN(alloc_nbr)
		  INTO	local_allocnbr
		  FROM	worklist
		 WHERE	alloc_nbr > 0;
	EXCEPTION WHEN NO_DATA_FOUND THEN
		local_allocnbr := 0;
	END;

	-- Results_header record deletion will cascade through results_locations and results_detail;
	IF (local_allocnbr > 0) THEN
		DELETE FROM results_header
		 WHERE allocation_nbr < local_allocnbr;
	END IF;


	-- No shape tables should have a worklist key
	-- less than the minimum on the worklist
	BEGIN
		SELECT	MIN(wl_key)
		  INTO	min_wlkey
		  FROM	worklist
		 WHERE	wl_key > 0;
		 EXCEPTION WHEN NO_DATA_FOUND THEN
			NULL;
	 END;

	-- Delete from all shape tables where wl_key < min_wlkey.
	-- If this fails, will log an error and return false. May want to handle this....
  -- There's no need to call PrepareForWorkListDelete here, as we're not deleting from the WorkList
	v_bSuccess	:= 	AllocMMS.DeleteWLKeys(' < ' || min_wlkey, FALSE);

	COMMIT;
END proc_clean_results;

/************************************************************************************************
***************************** Start of Table Cloning Routines *************************
************************************************************************************************/

-- create function for reading a table index
FUNCTION get_table_index (
  p_iname  user_ind_columns.index_name%TYPE,
  p_prefix user_ind_columns.table_name%TYPE := NULL)
  RETURN  VARCHAR2 IS
    v_retval VARCHAR2(2048); -- return value
BEGIN
  -- build a statement like:
  --   users (user_id)
  -- as used when creating foreign key.
  FOR v_rec IN (SELECT table_name, column_name
                 FROM user_ind_columns
                 WHERE index_name = upper(p_iname)
                 ORDER BY column_position)
  LOOP
    IF length(v_retval) > 0 THEN
      v_retval := v_retval || ', ';
    ELSIF length(v_rec.column_name) > 0 THEN
      IF p_prefix IS NULL THEN
        -- table index will start with table name
        v_retval := v_rec.table_name || ' (';
      ELSE
        -- table index will start with prefix
        v_retval := p_prefix || ' (';
      END IF;
    END IF;
    -- append the next column
    v_retval := v_retval || v_rec.column_name;
  END LOOP;
  -- close parenthesis
  IF length(v_retval) > 0 THEN
    v_retval := v_retval || ')';
  END IF;
  RETURN v_retval;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL; --
END get_table_index;


-- create function for reading a constraint columns
FUNCTION get_cons_cols (
  p_cname  user_cons_columns.constraint_name%TYPE,
  p_prefix user_cons_columns.table_name%TYPE := NULL)
  RETURN  VARCHAR2 IS
    v_retval VARCHAR2(2048); -- return value
BEGIN
  -- build a statement like:
  --   users (user_id)
  -- as used when creating key.
  FOR v_rec IN (SELECT column_name
                 FROM user_cons_columns
                 WHERE constraint_name = upper(p_cname)
                 ORDER BY position)
  LOOP
    IF length(v_retval) > 0 THEN
      v_retval := v_retval || ', ';
    ELSIF length(v_rec.column_name) > 0 THEN
      IF p_prefix IS NULL THEN
        -- fkey cols will start with paren only
        v_retval := '(';
      ELSE
        -- fkey cols will start with prefix
        v_retval := p_prefix || ' (';
      END IF;
    END IF;
    -- append the next column
    v_retval := v_retval || v_rec.column_name;
  END LOOP;
  -- close parenthesis
  IF length(v_retval) > 0 THEN
    v_retval := v_retval || ')';
  END IF;
  RETURN v_retval;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL; --
END get_cons_cols;


-- helper to determine minumum value
FUNCTION MinVal(
  p_Val1 NUMBER,
  p_Val2 NUMBER,
  p_Def  NUMBER)
  RETURN NUMBER IS
BEGIN
  IF (p_Val2 IS NULL AND p_Val1 IS NOT NULL) OR (p_Val1 IS NOT NULL AND (p_Val1 <= p_Val2))
  THEN
    RETURN p_Val1;
  ELSIF (p_Val1 IS NULL AND p_Val2 IS NOT NULL) OR (p_Val2 IS NOT NULL AND (p_Val2 <= p_Val1))
  THEN
    RETURN p_Val2;
  ELSE
    RETURN p_Def; -- default
  END IF;
END MinVal;


-- create helper function for retrieving index storage
-- [note: returns null if not staging or format table]
-- [UPDATE: returns a minimum rather than null string]
FUNCTION get_istorage (
  p_ctype user_constraints.constraint_type%TYPE,
  p_iname user_indexes.index_name%TYPE)
  RETURN  VARCHAR2 IS
    v_retval   VARCHAR2(32000);     -- return value
    v_DefFmtHy NUMBER := 32 * 1024; -- default size for format and history
    v_DefOther NUMBER := 16 * 1024; -- default size
BEGIN
  BEGIN

    SELECT
      decode(p_ctype,
             'R', '',
             decode(p_ctype,
                    NULL, '',
                    ' USING INDEX '
                    )
             || 'TABLESPACE    ' || TABLESPACE_NAME || CHR(10)
             || 'STORAGE ( '                        || CHR(10)
             || '  INITIAL     ' || MinVal(INITIAL_EXTENT,v_DefFmtHy,v_DefFmtHy) || CHR(10)
             || '  NEXT        ' || MinVal(NEXT_EXTENT,v_DefFmtHy,v_DefFmtHy)    || CHR(10)
             || '  MINEXTENTS  ' || MIN_EXTENTS     || CHR(10)
             || '  MAXEXTENTS  ' || MAX_EXTENTS     || CHR(10)
             || ')'
             )
      INTO v_retval
      FROM user_indexes
      WHERE index_name = upper(p_iname)
        AND table_name IN ('ACTUAL_FORMAT','STAGE_V_DEPT','STAGE_V_SUBDEPT','STAGE_V_CLASS',
        'STAGE_SUBCLASS','STAGE_V_SKU','STAGE_V_COLOR','STAGE_V_SIZE','STAGE_DIMENSION');

  EXCEPTION
    WHEN OTHERS THEN
      NULL; -- this was likely a no_data_found error; i.e. not format or history
  END;

  -- rather than returning null thus causing use of default settings for
  -- default tablespace, it is better for us to explicitly specify what
  -- the default values we prefer are.
  IF v_retval IS NULL THEN
    SELECT
      decode(p_ctype,
             'R', '',
             decode(p_ctype,
                    NULL, '',
                    ' USING INDEX '
                    )
             || 'TABLESPACE    ' || TABLESPACE_NAME || CHR(10)
             || 'STORAGE ( '                        || CHR(10)
             || '  INITIAL     ' || MinVal(INITIAL_EXTENT,v_DefOther,v_DefOther) || CHR(10)
             || '  NEXT        ' || MinVal(NEXT_EXTENT,v_DefOther,v_DefOther)    || CHR(10)
             || '  MINEXTENTS  ' || MIN_EXTENTS     || CHR(10)
             || '  MAXEXTENTS  ' || MAX_EXTENTS     || CHR(10)
             || ')'
             )
      INTO v_retval
      FROM user_indexes
      WHERE index_name = upper(p_iname);
  END IF;

  RETURN v_retval;
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL; -- table not found
END get_istorage;


------------------------------------------------------------------------------


--
-- This procedue must not add a trailing slash '/' to the the
-- generated DDL.  This causes problems when you try to invoke
-- the DDL from Native Dynamic SQL.
--
PROCEDURE PopulateObjects (
  p_table_name user_tables.table_name%TYPE)
  AS
ddl1 LONG;
ddl2 LONG;
ddl3 LONG;
-- * GSM02 Added by GSM to include privilege grants *
ddl4 LONG;
BEGIN

-- * GSM02 Added by GSM to include privilege grants *
ddl4 :=
 'INSERT INTO AllocMMS$OBJECTS ' || CHR(10) ||
 ' SELECT ' ||
 ''' GRANT '' || PRIVILEGE || '' ON '' || TABLE_SCHEMA ||
 ''.'' || TABLE_NAME || '' to '' || GRANTEE ' || CHR(10)  ||
 'FROM ALL_TAB_PRIVS ' || CHR(10)  ||
 'WHERE GRANTOR = USER' || CHR(10)  ||
 '  AND TABLE_NAME = upper(''' || p_table_name || ''') ';

 EXECUTE IMMEDIATE ddl4;
-- * GSM02 end *

-- handle creation of keys for this table
ddl1 := 'INSERT INTO AllocMMS$OBJECTS ' ||
'SELECT  ' ||
     '''ALTER TABLE '' || x.table_name || '' ADD ('' || CHR(10) ' ||
  '|| ''CONSTRAINT '' ' ||
  '|| x.constraint_name || CHR(10)  ' ||
  '|| '' ''  ' ||
  '|| AllocMMS.get_cons_cols(x.constraint_name, ' ||
                   'decode(x.constraint_type,  ' ||
                          '''R'', ''FOREIGN KEY'', ' ||
                          '''P'', ''PRIMARY KEY'', ' ||
                          '''U'', ''UNIQUE'', ' ||
                          '''{unsupported}'' ' ||
                          ') ' ||
                   ') ' ||
  '|| decode(x.constraint_type,  ' ||
            '''R'', CHR(10) || '' REFERENCES '' || AllocMMS.get_table_index(x.r_constraint_name)  ' ||
                         '|| decode(x.delete_rule, ' ||
                                   '''CASCADE'', '' '' || CHR(10) || '' ON DELETE CASCADE'', ' ||
                                   ''''' ' ||
                                   '), ' ||
            ''''' ' ||
            ') ' ||
  '|| CHR(10) ||  ' ||
  'AllocMMS.get_istorage(x.constraint_type, i.index_name) ' ||
  '|| '')''  ' ||
  --'|| CHR(10) || ''/ '' || CHR(10) || CHR(10) ' ||
  'AS index_command ' ||
'FROM  ' ||
  'user_constraints x, ' ||
  'user_indexes i ' ||
'WHERE x.table_name      = upper(''' || p_table_name || ''') ' ||
  'AND x.table_name      = i.table_name (+) ' ||
  'AND x.constraint_name = i.index_name (+) ' ||
  'AND x.constraint_type IN (''P'', ''U'') ' ;

  EXECUTE IMMEDIATE ddl1;


-- handle creation of keys for this table
ddl2 := 'INSERT INTO AllocMMS$OBJECTS ' ||
'SELECT  ' ||
     '''ALTER TABLE '' || x.table_name || '' ADD ('' || CHR(10) ' ||
  '|| ''CONSTRAINT '' ' ||
  '|| x.constraint_name || CHR(10)  ' ||
  '|| '' ''  ' ||
  '|| AllocMMS.get_cons_cols(x.constraint_name, ' ||
                   'decode(x.constraint_type,  ' ||
                          '''R'', ''FOREIGN KEY'', ' ||
                          '''P'', ''PRIMARY KEY'', ' ||
                          '''U'', ''UNIQUE'', ' ||
                          '''{unsupported}'' ' ||
                          ') ' ||
                   ') ' ||
  '|| decode(x.constraint_type,  ' ||
            '''R'', CHR(10) || '' REFERENCES '' || AllocMMS.get_cons_cols(x.r_constraint_name)  ' ||
                         '|| decode(x.delete_rule, ' ||
                                   '''CASCADE'', '' '' || CHR(10) || '' ON DELETE CASCADE'', ' ||
                                   ''''' ' ||
                                   '), ' ||
            ''''' ' ||
            ') ' ||
  '|| CHR(10) ||  ' ||
  'AllocMMS.get_istorage(x.constraint_type, i.index_name) ' ||
  '|| '')''  ' ||
  --'|| CHR(10) || ''/ '' || CHR(10) || CHR(10) ' ||
  'AS index_command ' ||
'FROM  ' ||
  'user_constraints x, ' ||
  'user_indexes i ' ||
'WHERE x.table_name      = upper(''' || p_table_name || ''') ' ||
  'AND x.table_name      = i.table_name (+) ' ||
  'AND x.constraint_name = i.index_name (+) ' ||
  'AND x.constraint_type = ''R''  ' ;

  EXECUTE IMMEDIATE ddl2;


-- handle creation of indexes for this table
-- the purpose of joining to constraints is
-- to find those indexes that are not unique
-- nor primary key *constraints*. Unfortunately
-- AAL has a quirk of naming it's indexes based
-- on foreign keys with the same name. Thus, this
-- code block may appear wierd!
ddl3 := 'INSERT INTO AllocMMS$OBJECTS ' ||
'SELECT  ' ||
    '''CREATE'' || decode(i.uniqueness, ''UNIQUE'', '' UNIQUE'', '''') || '' INDEX '' ' ||
  '|| i.index_name  ' ||
  '|| CHR(10) || '' ''  ' ||
  '|| AllocMMS.get_table_index(i.index_name, ''ON '' || i.table_name) ' ||
  '|| CHR(10)  ' ||
  '|| AllocMMS.get_istorage(NULL, i.index_name) ' ||
  --'|| CHR(10) || ''/ '' || CHR(10) || CHR(10) ' ||
  'AS index_command ' ||
'FROM  ' ||
  'user_indexes i,  ' ||
  'user_constraints x ' ||
'WHERE i.table_name         = upper(''' || p_table_name || ''') ' ||
  'AND x.table_name      (+)= i.table_name  ' ||
  'AND x.constraint_name (+)= i.index_name ' ||
  'AND (x.constraint_type IS NULL ' ||
       'OR x.constraint_type = ''R'') ' ;

EXECUTE IMMEDIATE ddl3;

EXCEPTION
  WHEN OTHERS THEN
    NULL; -- table not found
END PopulateObjects;


PROCEDURE ClearObjects AS
BEGIN
     EXECUTE IMMEDIATE 'DELETE FROM AllocMMS$OBJECTS';

EXCEPTION
         WHEN OTHERS THEN
         NULL;
END ClearObjects;

-- This function will get the DDL for the Indexes and Keys for a given table.

--
-- This function will get the DDL for the Indexes and Keys for a given table.
--
FUNCTION GetTableIndexAndKeyDDL(tableName VARCHAR2) RETURN DDL_tabType AS
         TYPE cv_typ IS REF CURSOR;
         cv cv_typ;
         ddlTable DDL_tabType;
         ddlText LONG;
         ddlLineIndex PLS_INTEGER := 0;
BEGIN
    ClearObjects;
    PopulateObjects(tableName);

    OPEN cv FOR 'SELECT t.ddl_statement FROM AllocMMS$OBJECTS t';

    LOOP
        FETCH cv INTO ddlTable(ddlLineIndex);
        EXIT WHEN cv%NOTFOUND;
        ddlLineIndex := ddlLineIndex + 1;
    END LOOP;

  RETURN ddlTable;

EXCEPTION
  WHEN OTHERS THEN
  RETURN ddlTable;
END GetTableIndexAndKeyDDL;

--
-- This function will take the DDL generated by GetTableIndexAndKeyDDL() and
-- execute it.
--
PROCEDURE ExecutedIndexAndKeyDDL(ddlTable DDL_tabType) AS
          loopIndex PLS_INTEGER := 0;
BEGIN

  WHILE ddlTable(loopIndex) IS NOT NULL
  LOOP
      EXECUTE IMMEDIATE ddlTable(loopIndex);
      loopIndex := loopIndex + 1;
  END LOOP;

EXCEPTION
  -- This just means that we ran off the end of the table
  WHEN NO_DATA_FOUND THEN
  RETURN;
END ExecutedIndexAndKeyDDL;

/************************************************************************************************
***************************** End of Table Cloning Routines *************************
************************************************************************************************/

/***********************************************************************************************/

-- This function is used internally ONLY! DO NOT export it!
PROCEDURE LogColError (
	p_arrStatus		IN VARCHAR2,
	p_arrMessage	IN VARCHAR2)
IS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	INSERT INTO log_table (status, e_message)
		 VALUES	(p_arrStatus, p_arrMessage);

	COMMIT;
END LogColError;


FUNCTION TruncateTable(
	p_TableName		IN user_tables.table_name%TYPE)
RETURN BOOLEAN IS
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
	EXECUTE IMMEDIATE
		'TRUNCATE TABLE ' || p_TableName;

	RETURN TRUE;
EXCEPTION
	WHEN OTHERS THEN
		RETURN FALSE;
END TruncateTable;


FUNCTION DeleteWLKeys(
	p_arrWhereClause	IN VARCHAR2,
	p_bDeleteFromWL		IN BOOLEAN DEFAULT TRUE)
RETURN BOOLEAN IS
PRAGMA AUTONOMOUS_TRANSACTION;
	-- What shape tables does Allocation know about?
	v_arrWLKey		VARCHAR2(50);
	v_arrStatusError	log_table.status%TYPE	:= 'WLKey deletion error.';
	v_arrProcName		VARCHAR2(35)			:= 'DeleteWLKeys';
	idx NUMBER := 1;
	TYPE table_names IS VARRAY(4) OF VARCHAR2(50);
	v_table_names table_names;
BEGIN
	v_table_names := table_names('PACK_COLOR','PACK_SIZE','PACK_DIMENSION','PACK_STYLE');

	FOR idx IN 1..4 LOOP
		-- What is the wl_key column name on the given shape table?
		v_arrWLKey	:= 'WL_KEY';
		IF v_arrWLKey IS NULL THEN
			LogColError(v_arrStatusError, v_arrProcName || ': There is no mapping for the WLKey column on shape table ''' || v_table_names(idx) || '''.' );
			RETURN FALSE;
		END IF;

		EXECUTE IMMEDIATE
			'DELETE ' || v_LF ||
			'  FROM ' || v_table_names(idx)|| v_LF ||
			' WHERE ' || v_arrWLKey || ' ' || p_arrWhereClause;
	END LOOP;

	-- Are we to delete the wl_key record from the worklist?
	IF p_bDeleteFromWL THEN
		-- What is the wl_key column name on the worklist?
		v_arrWLKey	:= 'WL_KEY';
		IF v_arrWLKey IS NULL THEN
			LogColError(v_arrStatusError, v_arrProcName || ': There is no mapping for the WLKey column on the WorkList.' );
			RETURN FALSE;
		END IF;

		-- Get rid of the record for the given WL_key(s) on the worklist table.
		EXECUTE IMMEDIATE
			'DELETE ' || v_LF ||
			'  FROM worklist ' || v_LF ||
			' WHERE ' || v_arrWLKey || ' ' ||  p_arrWhereClause;
	END IF;

	COMMIT;

	RETURN TRUE;
EXCEPTION
	WHEN OTHERS THEN
		LogColError(v_arrStatusError, v_arrProcName || ': General Error [' || SQLERRM || '].');
		RETURN FALSE;
END DeleteWLKeys;


FUNCTION GetListName (
	p_iGroup		IN NUMBER,
	p_Values		IN AllocMMS.t_FieldNamesArray)
RETURN VARCHAR2 IS
	c_rCursor				t_rCursor;
	v_arrListSourceTable	VARCHAR2(30);
	v_arrCodeColumnName		VARCHAR2(50);
	v_arrDescColumnName		VARCHAR2(50);
	v_arrColumnName			VARCHAR2(50);
	v_GroupNbr				NUMBER      ;

	v_arrWhereClause		VARCHAR2(500);
	v_arrDescription		VARCHAR2(100);
	v_arrTempDesc			VARCHAR2(100);

	v_arrStatusError	VARCHAR2(25)	:= 'List source Error.';
	v_arrProcName		VARCHAR2(35)	:= 'GetListName';
	v_Count			NUMBER ;
    TYPE GroupArray	 IS VARRAY(5) OF NUMBER;
    v_GroupArray GroupArray;
    TYPE ColumnNameArray IS VARRAY(5) OF VARCHAR2(50);
    v_ColumnNameArray ColumnNameArray;
    nCount NUMBER;
    idx  NUMBER;
BEGIN
	-- What list source table are we going to look in?

	BEGIN
	    -- retrieve the list source table name from the rtmm group table
		case p_iGroup
		  when 1 then v_arrListSourceTable := 'LIST_DEPT';
		  when 2 then v_arrListSourceTable := 'LIST_SUBDEPT';
		  when 3 then v_arrListSourceTable := 'LIST_CLASS';
           when 4 then v_arrListSourceTable := 'LIST_ITEM_GROUP';
		  when 5 then v_arrListSourceTable := 'LIST_SUBCLASS';
          when 6 then v_arrListSourceTable := 'LIST_CHOICE';
		  when 7 then v_arrListSourceTable := 'LIST_SKU';
		  when 8 then v_arrListSourceTable := 'LIST_COLOR';
		  when 9 then v_arrListSourceTable := 'LIST_SIZE';
		  when 10 then v_arrListSourceTable := 'LIST_DIM';
		  when 11 then v_arrListSourceTable := 'ATTRIBUTE_CGR';
		  else v_arrListSourceTable := NULL;
		end case;
    END;

	-- We can get a null value for the list source, which means that there is no
	-- associated table for the group you want. Hence there is no string associated
	-- with the code wanted.
	IF v_arrListSourceTable IS NULL THEN
		RETURN ' ';
	END IF;

	-- What are the code and description column names for the given list table?
	BEGIN
	   case p_iGroup
		  when 1 then v_arrCodeColumnName := 'DEPT_NBR';
		  when 2 then v_arrCodeColumnName := 'SUBDEPT_NBR';
		  when 3 then v_arrCodeColumnName := 'CLASS_NBR';
          when 4 then v_arrListSourceTable := 'LIST_ITEM_GROUP';
		  when 5 then v_arrCodeColumnName := 'SUBCLASS_NBR';
          when 6 then v_arrListSourceTable := 'LIST_CHOICE';
		  when 7 then v_arrCodeColumnName := 'STYLE_MASTER_SKU';
		  when 8 then v_arrCodeColumnName := 'COLOR_NBR';
		  when 9 then v_arrCodeColumnName := 'SIZE_NBR';
		  when 10 then v_arrCodeColumnName := 'DIM_NBR';
		  when 11 then v_arrCodeColumnName := 'COORD_GROUP_CODE';
		  else v_arrCodeColumnName := NULL;
		end case;

	EXCEPTION
		WHEN OTHERS THEN
			LogColError(v_arrStatusError, v_arrProcName || ': Missing code column mapping for group #' || p_iGroup || ' on table ' || v_arrListSourceTable || '.');
			RETURN ' ';
	END;

	DECLARE
	attr_Nbr_D2 NUMBER := 0;
	BEGIN
	   case p_iGroup
		  when 1 then attr_Nbr_D2 := 2;
		  when 2 then attr_Nbr_D2 := 3;
		  when 3 then attr_Nbr_D2 := 4;
		  when 4 then attr_Nbr_D2 := 5;
		  when 5 then attr_Nbr_D2 := 6;
          when 6 then attr_Nbr_D2 := 7;
          when 7 then attr_Nbr_D2 := 8;
		  when 8 then attr_Nbr_D2 := 2;
		  when 9 then attr_Nbr_D2 := 2;
		  when 10 then attr_Nbr_D2 := 2;
		  when 11 then attr_Nbr_D2 := 2;
		  else attr_Nbr_D2 := 0;
		end case;

	   case v_arrListSourceTable
		  when 'LIST_DEPT' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'DEPT_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
		  when 'LIST_SUBDEPT' then
		   IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'SUBDEPT_NBR';
			ELSE IF attr_Nbr_D2 = 3 THEN
				v_arrDescColumnName	:= 'SUBDEPT_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
			END IF;
		  when 'LIST_CLASS' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'SUBDEPT_NBR';
			ELSE IF attr_Nbr_D2 = 3 THEN
				v_arrDescColumnName	:= 'CLASS_NBR';
			ELSE IF attr_Nbr_D2 = 4 THEN
				v_arrDescColumnName	:= 'CLASS_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;	END IF;	END IF;
            when 'LIST_ITEM_GROUP' then
          IF attr_Nbr_D2 = 2 THEN
                v_arrDescColumnName := 'SUBDEPT_NBR';
            ELSE IF attr_Nbr_D2 = 3 THEN
                v_arrDescColumnName    := 'CLASS_NBR';
            ELSE IF attr_Nbr_D2 = 4 THEN
            v_arrDescColumnName    := 'ITEM_GROUP_NBR';
            ELSE IF attr_Nbr_D2 = 5 THEN
                v_arrDescColumnName    := 'ITEM_GROUP_NAME';
            ELSE
                v_arrDescColumnName    := NULL;
            END IF;    END IF;    END IF; END IF;
		  when 'LIST_SUBCLASS' then
		   IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'SUBDEPT_NBR';
			ELSE IF attr_Nbr_D2 = 3 THEN
				v_arrDescColumnName	:= 'CLASS_NBR';
			ELSE IF attr_Nbr_D2 = 4 THEN
				v_arrDescColumnName	:= 'SUBCLASS_NBR';
			ELSE IF attr_Nbr_D2 = 5 THEN
				v_arrDescColumnName	:= 'SUBCLASS_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;	END IF;	END IF;	END IF;
             when 'LIST_CHOICE' then
           IF attr_Nbr_D2 = 2 THEN
                v_arrDescColumnName := 'SUBDEPT_NBR';
            ELSE IF attr_Nbr_D2 = 3 THEN
                v_arrDescColumnName    := 'CLASS_NBR';
           ELSE IF attr_Nbr_D2 = 4 THEN
                v_arrDescColumnName    := 'ITEM_GROUP_NBR';
            ELSE IF attr_Nbr_D2 = 5 THEN
                v_arrDescColumnName    := 'SUBCLASS_NBR';
            ELSE IF attr_Nbr_D2 = 6 THEN
                v_arrDescColumnName    := 'CHOICE_NBR';
            ELSE IF attr_Nbr_D2 = 7 THEN
                v_arrDescColumnName    := 'CHOICE_NAME';
            ELSE
                v_arrDescColumnName    := NULL;
            END IF;    END IF;    END IF;    END IF; END IF; END IF;
		  when 'LIST_SKU' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'SUBDEPT_NBR';
			ELSE IF attr_Nbr_D2 = 3 THEN
				v_arrDescColumnName	:= 'CLASS_NBR';
            ELSE IF attr_Nbr_D2 = 4 THEN
                v_arrDescColumnName    := 'ITEM_GROUP_NBR';
			ELSE IF attr_Nbr_D2 = 5 THEN
				v_arrDescColumnName	:= 'SUBCLASS_NBR';
            ELSE IF attr_Nbr_D2 = 6 THEN
                v_arrDescColumnName    := 'CHOICE_NBR';
			ELSE IF attr_Nbr_D2 = 7 THEN
				v_arrDescColumnName	:= 'STYLE_MASTER_SKU';
			ELSE IF attr_Nbr_D2 = 8 THEN
				v_arrDescColumnName	:= 'PRODUCT_NBR';
			ELSE IF attr_Nbr_D2 = 9 THEN
				v_arrDescColumnName	:= 'PRODUCT_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;	END IF;	END IF;	END IF;	END IF;	END IF; END IF; END IF;
		  when 'LIST_COLOR' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'COLOR_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
		  when 'LIST_SIZE' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'SIZE_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
		  when 'LIST_DIM' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'DIM_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
		  when 'ATTRIBUTE_CGR' then
		  IF attr_Nbr_D2 = 2 THEN
				v_arrDescColumnName := 'COORD_GROUP_NAME';
			ELSE
				v_arrDescColumnName	:= NULL;
			END IF;
		  else v_arrDescColumnName := NULL;
		end case;

	EXCEPTION
		WHEN OTHERS THEN
			LogColError(v_arrStatusError, v_arrProcName || ': Missing description column mapping for group #' || p_iGroup || ' on table ' || v_arrListSourceTable || '.');
			RETURN ' ';
	END;


	-- What are the group numbers that we have to look in the parameter table for?

	case v_arrListSourceTable

		  when 'LIST_DEPT' then
		  v_GroupArray := GroupArray(1);
		  v_ColumnNameArray := ColumnNameArray('DEPT_NBR');

		  when 'LIST_SUBDEPT' then
		  v_GroupArray := GroupArray(1,2);
		  v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR');

		  when 'LIST_CLASS' then
		  v_GroupArray := GroupArray(1,2,3);
		  v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR','CLASS_NBR');

          when 'LIST_ITEM_GROUP' then
          v_GroupArray := GroupArray(1,2,3,4);
          v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR','CLASS_NBR','ITEM_GROUP_NBR');

		  when 'LIST_SUBCLASS' then
		  v_GroupArray := GroupArray(1,2,3,4,5);
		  v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR','CLASS_NBR','ITEM_GROUP_NBR','SUBCLASS_NBR');

          when 'LIST_CHOICE' then
          v_GroupArray := GroupArray(1,2,3,4,5,6);
          v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR','CLASS_NBR','ITEM_GROUP_NBR','SUBCLASS_NBR','CHOICE_NBR');
		  when 'LIST_SKU' then
		  v_GroupArray := GroupArray(1,2,3,4,5,6,7);
		  v_ColumnNameArray := ColumnNameArray('DEPT_NBR','SUBDEPT_NBR','CLASS_NBR','ITEM_GROUP_NBR','SUBCLASS_NBR','CHOICE_NBR','STYLE_MASTER_SKU');

		  when 'LIST_COLOR' then
		  v_GroupArray := GroupArray(1);
		  v_ColumnNameArray := ColumnNameArray('COLOR_NBR');

		  when 'LIST_SIZE' then
		  v_GroupArray := GroupArray(1);
		  v_ColumnNameArray := ColumnNameArray('SIZE_NBR');

		  when 'LIST_DIM' then
		  v_GroupArray := GroupArray(1);
		  v_ColumnNameArray := ColumnNameArray('DIM_NBR');

		  when 'ATTRIBUTE_CGR' then
		  v_GroupArray := GroupArray(1);
		  v_ColumnNameArray := ColumnNameArray('COORD_GROUP_CODE');

		end case;

		v_Count := 0;
		idx := NULL;
		idx := v_GroupArray.First;
			WHILE idx IS NOT NULL  LOOP
				v_GroupNbr := v_GroupArray(v_Count);
				v_arrColumnName := v_ColumnNameArray(v_Count);
				-- If the group is mapped in the list source, and that group was specified
				-- in p_Values, then add the value to the where clause.
				IF p_Values.EXISTS(v_GroupNbr) THEN
					-- Do we need to append another clause?
					IF v_arrWhereClause IS NOT NULL THEN
						v_arrWhereClause := v_arrWhereClause || v_LF || '  AND ';
					ELSE
						v_arrWhereClause	:= ' WHERE ';
					END IF;
					v_arrWhereClause	:= v_arrWhereClause || v_arrColumnName || ' = ''' || p_Values(v_GroupNbr) || '''';
				END IF;
				v_Count := v_Count+1;
				idx := v_GroupArray.Next(idx);
			END LOOP;

	OPEN c_rCursor FOR
		'SELECT	DISTINCT(' || v_arrDescColumnName || ')' || v_LF ||
		'  FROM	' || v_arrListSourceTable || v_LF ||
		v_arrWhereClause;

	FETCH c_rCursor INTO v_arrDescription;

	IF c_rCursor%FOUND THEN
		FETCH c_rCursor INTO v_arrTempDesc;

		IF c_rCursor%FOUND THEN
			LogColError(v_arrStatusError, v_arrProcName || ': More than one value found when looking up values ''' || SUBSTR(v_arrWhereClause, 7) || ''' in list souce table ''' || v_arrListSourceTable || '''.');
		END IF;
	ELSE
		v_arrDescription	:= ' ';
	END IF;

	CLOSE c_rCursor;

	RETURN v_arrDescription;
EXCEPTION
	-- If anything happens to go wrong, just return an empty string.
	WHEN OTHERS THEN
		RETURN ' ';
END GetListName;


FUNCTION SumTableColumn (
	p_arrTableName		IN VARCHAR2,
	p_arrColumnName		IN VARCHAR2,
	p_iWLKey			IN NUMBER	DEFAULT NULL)
RETURN NUMBER IS
	v_arrWLKeyColumn	VARCHAR2(50) := NULL;
	v_arrWhereClause	VARCHAR2(50)	:= '';
	v_iSumValue			NUMBER;
BEGIN
	IF p_iWLKey IS NOT NULL THEN
		v_arrWLKeyColumn	:= 'WL_KEY';

		IF v_arrWLKeyColumn IS NULL THEN
			RETURN 0;
		END IF;

		v_arrWhereClause	:= ' WHERE ' || v_arrWLKeyColumn || ' = ' || p_iWLKey;
	END IF;

	EXECUTE IMMEDIATE
		'SELECT SUM(' || p_arrColumnName || ')' || v_LF ||
		'  FROM	' || p_arrTableName || v_LF ||
		v_arrWhereClause
		INTO v_iSumValue;

	RETURN NVL(v_iSumValue, 0);
EXCEPTION
	-- If anything bad happens, just return 0.
	WHEN OTHERS THEN
		RETURN 0;
END SumTableColumn;


FUNCTION GetMerchShapeTableFromMerchID (
	p_iMerchID		IN	NUMBER,
	p_arrShapeTable	OUT VARCHAR2)
RETURN BOOLEAN IS
	v_arrShapeTable	unique_key_header.table_name%TYPE;
BEGIN
	IF p_iMerchID IS NULL THEN
		p_arrShapeTable	:= NULL;
		RETURN FALSE;
	END IF;

	SELECT	table_name
	  INTO	p_arrShapeTable
	  FROM	unique_key_header
	 WHERE	mer_type = p_iMerchID;

	RETURN TRUE;
EXCEPTION
	WHEN OTHERS THEN
		p_arrShapeTable	:= NULL;
		RETURN FALSE;
END GetMerchShapeTableFromMerchID;


FUNCTION GetMerchShapeTypeFromMerchID (p_iMerchID	IN NUMBER)
RETURN VARCHAR2 IS
	v_ShapeType		unique_key_header.bulk_pack_flag%TYPE;
BEGIN
	IF p_iMerchID IS NULL THEN
		RETURN NULL;
	END IF;

	SELECT	bulk_pack_flag
	  INTO	v_ShapeType
	  FROM	unique_key_header
	 WHERE	mer_type = p_iMerchID;

	RETURN v_ShapeType;
EXCEPTION
	WHEN OTHERS THEN
		RETURN NULL;
END GetMerchShapeTypeFromMerchID;


FUNCTION DoesColumnExistOnTable(
	p_arrTableName		IN VARCHAR2,
	p_arrColumnName		IN VARCHAR2)
RETURN BOOLEAN IS
	v_Exists		NUMBER	:= 0;
BEGIN
	IF p_arrTableName IS NULL OR p_arrColumnName IS NULL THEN
		RETURN FALSE;
	END IF;

   case p_arrTableName
		  when 'WORKLIST' then
		    IF p_arrColumnName = 'ON_ORDER_BALANCE' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'NBR_PACKS' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'QTY_PER_PACK' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'AVAIL_QTY' THEN
				v_Exists := 1;
			ELSE
				v_Exists := 0;
			END IF;	END IF;END IF;END IF;

		  when 'PACK_STYLE' then
		  IF p_arrColumnName = 'ON_ORDER_BALANCE' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'NBR_PACKS' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'QTY_PER_PACK' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'AVAIL_QTY' THEN
				v_Exists := 1;
			ELSE
				v_Exists := 0;
			END IF;	END IF;END IF;END IF;
		  when 'PACK_SIZE' then
		   IF p_arrColumnName = 'ON_ORDER_BALANCE' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'NBR_PACKS' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'QTY_PER_PACK' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'AVAIL_QTY' THEN
				v_Exists := 1;
			ELSE
				v_Exists := 0;
			END IF;	END IF;END IF;END IF;
		  when 'PACK_COLOR' then
		  IF p_arrColumnName = 'ON_ORDER_BALANCE' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'NBR_PACKS' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'QTY_PER_PACK' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'AVAIL_QTY' THEN
				v_Exists := 1;
			ELSE
				v_Exists := 0;
			END IF;	END IF;END IF;END IF;
		  when 'PACK_DIMENSION' then
		  IF p_arrColumnName = 'ON_ORDER_BALANCE' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'NBR_PACKS' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'QTY_PER_PACK' THEN
				v_Exists := 1;
			ELSE IF p_arrColumnName = 'AVAIL_QTY' THEN
				v_Exists := 1;
			ELSE
				v_Exists := 0;
			END IF;END IF;END IF;END IF;
		  else v_Exists := 0;
		end case;

	IF v_Exists = 1 THEN	-- This should be a value besides 1! We should only EVER get one record returned to us.
		RETURN TRUE;
	END IF;

	-- Default fail.
	RETURN FALSE;
EXCEPTION
	WHEN OTHERS THEN
		RETURN FALSE;
END DoesColumnExistOnTable;



FUNCTION SumColumnFromShapeToWorklist (
	p_arrWLColumnName		IN VARCHAR2,
	p_iWLKey				IN NUMBER	/*DEFAULT NULL*/,
	p_arrSTColumnName		IN VARCHAR2 DEFAULT NULL)
RETURN BOOLEAN IS
PRAGMA AUTONOMOUS_TRANSACTION;
	c_rCursor		t_rCursor;

	v_arrSTColumnName	VARCHAR2(50) := NULL;
	v_arrWLKeyColumn	VARCHAR2(50) := NULL;
	v_arrSTypeColumn	VARCHAR2(50) := NULL;
	v_arrShapeTable	    VARCHAR2(30) := NULL;
	v_iMerchID		NUMBER		:= NULL;
	v_iQty			NUMBER;
	v_bFound		BOOLEAN	:= FALSE;

	v_arrStatusError	VARCHAR2(25)	:= 'No column summing done.';
	v_arrProcName		VARCHAR2(35)	:= 'SumColumnFromShapeTableToWorklist';
BEGIN
	-- Let's make sure we get the right column name for the WLKey column on the Worklist table.
	v_arrWLKeyColumn	:= 'WL_KEY';
	v_arrSTypeColumn	:= 'SHAPE_TYPE';

	IF v_arrWLKeyColumn IS NULL OR v_arrSTypeColumn IS NULL THEN
		LogColError(v_arrStatusError, v_arrProcName || ': Missing column mapping for the WLKey or the ShapeType on the WorkList table.');
		RETURN FALSE;
	END IF;

	-- Let's make sure we have a valid column name (for the WL).
	IF NOT DoesColumnExistOnTable('WORKLIST', p_arrWLColumnName) THEN
		LogColError(v_arrStatusError, v_arrProcName || ': Column ''' || p_arrWLColumnName || 'does not exist on the WorkList table.');
		RETURN FALSE;
	END IF;

	-- Okay, do we even have a legimite(existing) shape type for the WLKey value?
	-- Since this is enclosed in a cursor, we don't need to handle any exceptions.
	OPEN c_rCursor FOR
		'SELECT ' || v_arrSTypeColumn || v_LF ||
		'  FROM worklist' || v_LF ||
		' WHERE	' || v_arrWLKeyColumn || ' = :WLKey'
		USING p_iWLKey;

	FETCH c_rCursor INTO v_iMerchID;

	IF c_rCursor%NOTFOUND THEN
		LogColError(v_arrStatusError, v_arrProcName || ': No data in the WorkList for the WLKey ' || p_iWLKey || '.');
		RETURN FALSE;
	ELSIF v_iMerchID IS NULL THEN
		LogColError(v_arrStatusError, v_arrProcName || ': No shape type for WorkList key ' || p_iWLKey || '.');
		RETURN FALSE;
	END IF;

	CLOSE c_rCursor;

	-- Now that we know the shape type, let's get the shape table name.
	v_bFound	:= GetMerchShapeTableFromMerchID(v_iMerchID, v_arrShapeTable);
	IF NOT v_bFound THEN
		LogColError(v_arrStatusError, v_arrProcName || ': For WorkList key ' || p_iWLKey || ', there was no shape of type ' || v_iMerchID || ' set up in Allocation.');
		RETURN FALSE;
	ELSIF v_arrShapeTable IS NULL THEN
		-- We have found the merchandise ID type, but there is no shape table
		-- associated with it. This means that the Merchandise ID Type uses the
		-- WL as the shape table (which is OK, it just doesn't make any sense to
		-- sum when the value is already there :).
		RETURN TRUE;
	END IF;

	-------------------------------------------------------------------------------------
	-- Now, let's make sure we have (or can get) a valid column name for the shape table.

	-- Do we have a column of the specified name on the shape table?
	IF p_arrSTColumnName IS NOT NULL THEN
		v_bFound	:= DoesColumnExistOnTable(v_arrShapeTable, p_arrSTColumnName);

		IF v_bFound THEN
			v_arrSTColumnName	:= p_arrSTColumnName;
		END IF;
	END IF;

	-- Next check if we have a column mapping on the WL. If so, try and use the same
	-- mapping from the Shape Table. If there is no WL column mapping, or the same one
	-- is not present on the Shape Table, then try and match the column name exactly.

	-- No shape table column was specified, or the one specified wasn't found.
	IF v_arrSTColumnName IS NULL THEN
		-- Check for a WL column mapping, and if it exists, see if there is a cooresponding
		-- mapping for the shape table.
		DECLARE
			v_LogicalFieldName	VARCHAR2(50) := NULL;
			attr_Nbr NUMBER := 0;
			attr_Nbr_1 NUMBER := 0;
		BEGIN
	   case p_arrWLColumnName
		  when 'ON_ORDER_BALANCE' then attr_Nbr := 25;
		  when 'NBR_PACKS' then attr_Nbr := 24;
		  when 'QTY_PER_PACK' then attr_Nbr := 21;
		  when 'AVAIL_QTY' then attr_Nbr := 20;
		  else attr_Nbr := 0;
		end case;

		case attr_Nbr
		  when 25 then v_LogicalFieldName := NULL;
		  when 24 then v_LogicalFieldName := 'LGF_WL_OPT_NO_OF_PACKS';
		  when 21 then v_LogicalFieldName := 'LGF_WL_OPT_QTY_PER_PACK';
		  when 20 then v_LogicalFieldName := 'LGF_WL_OPT_AVAIL_QTY';
		  else v_LogicalFieldName := NULL;
		end case;

		-- If we found a value, then try and find a cooresponding one
		-- for the cooresponding shape table.

		case v_arrShapeTable
		  when 'PACK_STYLE' then
		  IF v_LogicalFieldName = 'LGF_WL_OPT_NO_OF_PACKS' THEN
				attr_Nbr_1 := 5;
			ELSE IF v_LogicalFieldName = 'LGF_WL_OPT_QTY_PER_PACK' THEN
				attr_Nbr_1 := 6;
			ELSE
				attr_Nbr_1 := NULL;
			END IF;	END IF;

		  when 'PACK_COLOR' then
		  IF v_LogicalFieldName = 'LGF_WL_OPT_NO_OF_PACKS' THEN
				attr_Nbr_1 := 7;
			ELSE IF v_LogicalFieldName = 'LGF_WL_OPT_QTY_PER_PACK' THEN
				attr_Nbr_1 := 8;
			ELSE
				attr_Nbr_1 := NULL;
			END IF;	END IF;
		  when 'PACK_SIZE' then
		  IF v_LogicalFieldName = 'LGF_WL_OPT_NO_OF_PACKS' THEN
				attr_Nbr_1 := 9;
			ELSE IF v_LogicalFieldName = 'LGF_WL_OPT_QTY_PER_PACK' THEN
				attr_Nbr_1 := 10;
			ELSE
				attr_Nbr_1 := NULL;
			END IF;END IF;
		  when 'PACK_DIMENSION' then
		  IF v_LogicalFieldName = 'LGF_WL_OPT_NO_OF_PACKS' THEN
				attr_Nbr_1 := 11;
			ELSE IF v_LogicalFieldName = 'LGF_WL_OPT_QTY_PER_PACK' THEN
				attr_Nbr_1 := 12;
			ELSE
				attr_Nbr_1 := NULL;
			END IF;	END IF;
		  else
		  attr_Nbr_1 := NULL;
		end case;


		case v_arrShapeTable
		  when 'PACK_STYLE' then
		        IF attr_Nbr_1 = 5 THEN
				v_arrSTColumnName := 'NBR_PACKS';
			    ELSE IF attr_Nbr_1= 6 THEN
				v_arrSTColumnName := 'QTY_PER_PACK';
				ELSE IF attr_Nbr_1= 7 THEN
				v_arrSTColumnName := 'AVAIL_QTY';
				ELSE IF attr_Nbr_1= 8 THEN
				v_arrSTColumnName := 'ON_ORDER_BALANCE';
				ELSE IF attr_Nbr_1= 9 THEN
				v_arrSTColumnName := 'RETAIL_PRICE';
				ELSE IF attr_Nbr_1= 10 THEN
				v_arrSTColumnName := 'PO_LINE_COMMENTS';
				ELSE IF attr_Nbr_1= 11 THEN
				v_arrSTColumnName := NULL;
				ELSE IF attr_Nbr_1= 12 THEN
				v_arrSTColumnName := NULL;
			    ELSE
				v_arrSTColumnName := NULL;
			    END IF;END IF;END IF;END IF;END IF;	END IF;
			    END IF;	END IF;

		  when 'PACK_COLOR' then
		        IF attr_Nbr_1 = 5 THEN
				v_arrSTColumnName := 'COLOR_NAME';
			    ELSE IF attr_Nbr_1= 6 THEN
				v_arrSTColumnName := 'PACK_ID';
				ELSE IF attr_Nbr_1= 7 THEN
				v_arrSTColumnName := 'NBR_PACKS';
				ELSE IF attr_Nbr_1= 8 THEN
				v_arrSTColumnName := 'QTY_PER_PACK';
				ELSE IF attr_Nbr_1= 9 THEN
				v_arrSTColumnName := 'AVAIL_QTY';
				ELSE IF attr_Nbr_1= 10 THEN
				v_arrSTColumnName := 'ON_ORDER_BALANCE';
				ELSE IF attr_Nbr_1= 11 THEN
				v_arrSTColumnName := 'RETAIL_PRICE';
				ELSE IF attr_Nbr_1= 12 THEN
				v_arrSTColumnName := 'PO_LINE_COMMENTS';
			    ELSE
				v_arrSTColumnName := NULL;
			    END IF;END IF;END IF;END IF;END IF;	END IF;
			    END IF;	END IF;
		  when 'PACK_SIZE' then
		  IF attr_Nbr_1 = 5 THEN
				v_arrSTColumnName := 'COLOR_NAME';
			    ELSE IF attr_Nbr_1= 6 THEN
				v_arrSTColumnName := 'SIZE_NBR';
				ELSE IF attr_Nbr_1= 7 THEN
				v_arrSTColumnName := 'SIZE_NAME';
				ELSE IF attr_Nbr_1= 8 THEN
				v_arrSTColumnName := 'PACK_ID';
				ELSE IF attr_Nbr_1= 9 THEN
				v_arrSTColumnName := 'NBR_PACKS';
				ELSE IF attr_Nbr_1= 10 THEN
				v_arrSTColumnName := 'QTY_PER_PACK';
				ELSE IF attr_Nbr_1= 11 THEN
				v_arrSTColumnName := 'AVAIL_QTY';
				ELSE IF attr_Nbr_1= 12 THEN
				v_arrSTColumnName := 'ON_ORDER_BALANCE';
			    ELSE
				v_arrSTColumnName := NULL;
			    END IF;END IF;END IF;END IF;END IF;	END IF;
			    END IF;	END IF;
		  when 'PACK_DIMENSION' then
		        IF attr_Nbr_1 = 5 THEN
				v_arrSTColumnName := 'COLOR_NAME';
			    ELSE IF attr_Nbr_1= 6 THEN
				v_arrSTColumnName := 'SIZE_NBR';
				ELSE IF attr_Nbr_1= 7 THEN
				v_arrSTColumnName := 'SIZE_NAME';
				ELSE IF attr_Nbr_1= 8 THEN
				v_arrSTColumnName := 'DIM_NBR';
				ELSE IF attr_Nbr_1= 9 THEN
				v_arrSTColumnName := 'DIM_NAME';
				ELSE IF attr_Nbr_1= 10 THEN
				v_arrSTColumnName := 'PACK_ID';
				ELSE IF attr_Nbr_1= 11 THEN
				v_arrSTColumnName := 'NBR_PACKS';
				ELSE IF attr_Nbr_1= 12 THEN
				v_arrSTColumnName := 'QTY_PER_PACK';
			    ELSE
				v_arrSTColumnName := NULL;
			    END IF;END IF;END IF;END IF;END IF;	END IF;
			    END IF;	END IF;
		   else
		        v_arrSTColumnName := NULL;
		end case;

		EXCEPTION
			WHEN NO_DATA_FOUND THEN
				v_LogicalFieldName	:= NULL;
				v_arrSTColumnName		:= NULL;
		END;
	END IF;

	-- There was no WL column mapping, or the same one didn't exist on the shape table,
	-- so just try and match the names of the columns between the two.
	IF v_arrSTColumnName IS NULL AND DoesColumnExistOnTable(v_arrShapeTable, p_arrWLColumnName) THEN
		v_arrSTColumnName	:= p_arrWLColumnName;
	END IF;

	IF v_arrSTColumnName IS NULL THEN
		-- The column on the shape table to sum couldn't be determined from the information given,
		-- or it wasn't found.
		LogColError(v_arrStatusError, v_arrProcName || ': For worklist key ' || p_iWLKey || ', column ''' || p_arrWLColumnName || ''' the column to sum from the shape table ' ||
									v_arrShapeTable || ' could not be found or determined from the information given.');
		RETURN FALSE;
	END IF;

	-- What's the new sum for the column in the Worlist?
	v_iQty		:= SumTableColumn(v_arrShapeTable, v_arrSTColumnName, p_iWLKey);

	EXECUTE IMMEDIATE
		'UPDATE	worklist ' || v_LF ||
		'   SET	' || p_arrWLColumnName || ' = :Qty' || v_LF ||
		' WHERE	' || v_arrWLKeyColumn || ' = :WLKey'
		USING v_iQty, p_iWLKey;

	COMMIT;

	RETURN TRUE;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		ROLLBACK;

		LogColError(v_arrStatusError, v_arrProcName || ': General Error [' || SQLERRM || '].');
		RETURN FALSE;
END SumColumnFromShapeToWorklist;

/* The following proc_aalat% have been added by JDA (Abhi Sharma) on 7/11/2016 to incorporate
   Attribute functionality per CR changes */
---------------attribute interface begins --------------------------------------
PROCEDURE proc_aalat1 (p_bCalledForRebuild IN BOOLEAN)
   AS
      PRAGMA AUTONOMOUS_TRANSACTION;
   BEGIN
      DELETE FROM LIST_ATTR_1;

      INSERT INTO LIST_ATTR_1 (ATTR_1_CODE, ATTR_1_DESC)
         SELECT ATTR_1_CODE, ATTR_1_DESC
          FROM AALAT1
          WHERE OPERATION_CODE IN ('1');

      COMMIT;
END proc_aalat1;

PROCEDURE proc_aalat2 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_2;

  INSERT INTO LIST_ATTR_2 (ATTR_2_CODE, ATTR_2_DESC)
     SELECT ATTR_2_CODE, ATTR_2_DESC
       FROM AALAT2
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat2;

PROCEDURE proc_aalat3 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_3;

  INSERT INTO LIST_ATTR_3 (ATTR_3_CODE, ATTR_3_DESC)
     SELECT ATTR_3_CODE, ATTR_3_DESC
       FROM AALAT3
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat3;

PROCEDURE proc_aalat4 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_4;

  INSERT INTO LIST_ATTR_4 (ATTR_4_CODE, ATTR_4_DESC)
     SELECT ATTR_4_CODE, ATTR_4_DESC
       FROM AALAT4
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat4;


PROCEDURE proc_aalat5 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_5;

  INSERT INTO LIST_ATTR_5 (ATTR_5_CODE, ATTR_5_DESC)
     SELECT ATTR_5_CODE, ATTR_5_DESC
       FROM AALAT5
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat5;


PROCEDURE proc_aalat6 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_6;

  INSERT INTO LIST_ATTR_6 (ATTR_6_CODE, ATTR_6_DESC)
     SELECT ATTR_6_CODE, ATTR_6_DESC
       FROM AALAT6
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat6;

PROCEDURE proc_aalat7 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_7;

  INSERT INTO LIST_ATTR_7 (ATTR_7_CODE, ATTR_7_DESC)
     SELECT ATTR_7_CODE, ATTR_7_DESC
       FROM AALAT7
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat7;

PROCEDURE proc_aalat8 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_8;

  INSERT INTO LIST_ATTR_8 (ATTR_8_CODE, ATTR_8_DESC)
     SELECT ATTR_8_CODE, ATTR_8_DESC
       FROM AALAT8
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat8;

PROCEDURE proc_aalat9 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_9;

  INSERT INTO LIST_ATTR_9 (ATTR_9_CODE, ATTR_9_DESC)
     SELECT ATTR_9_CODE, ATTR_9_DESC
       FROM AALAT9
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat9;

PROCEDURE proc_aalat10 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_10;

  INSERT INTO LIST_ATTR_10 (ATTR_10_CODE, ATTR_10_DESC)
     SELECT ATTR_10_CODE, ATTR_10_DESC
       FROM AALAT10
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat10;

PROCEDURE proc_aalat11 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_11;

  INSERT INTO LIST_ATTR_11 (ATTR_11_CODE, ATTR_11_DESC)
     SELECT ATTR_11_CODE, ATTR_11_DESC
       FROM AALAT11
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat11;

PROCEDURE proc_aalat12 (p_bCalledForRebuild IN BOOLEAN)
AS
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  DELETE FROM LIST_ATTR_12;

  INSERT INTO LIST_ATTR_12 (ATTR_12_CODE, ATTR_12_DESC)
     SELECT ATTR_12_CODE, ATTR_12_DESC
       FROM AALAT12
      WHERE OPERATION_CODE IN ('1');

  COMMIT;
END proc_aalat12;
----------------attribute interface ends----------------------------------------

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

----------------model interface begins------------------------------------------
/* The following procedure (proc_aalmod) has been added by JDA (Abhi Sharma) on 7/20/2016 to
   incorporate the FM requirement as per the CR changes. The procedure will help
   leveraging the capacity and facing values currently available in Space Planning
   for use in calculating better allocations, respecting the minimum presentation
   unit set without overloading stores */
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
                  LOCATION_NUMBER,                                     
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

----------------model interface end---------------------------------------------

/************************************************************************************************/

BEGIN
	g_stPack(0)	:= const_style_shape;	  -- Style
	g_stPack(1)	:= const_color_shape;	  -- Color
	g_stPack(2)	:= const_size_shape;	  -- Size
	g_stPack(3)	:= const_dimension_shape; -- Dimension

	g_ListShapeTable(g_stPack(3))	:= 'PACK_DIMENSION';
	g_ListShapeTable(g_stPack(2))	:= 'PACK_SIZE';
	g_ListShapeTable(g_stPack(1))	:= 'PACK_COLOR';
	g_ListShapeTable(g_stPack(0))	:= 'PACK_STYLE';

 -- Make sure that this temporary table is created.
  BEGIN
       EXECUTE IMMEDIATE 'create GLOBAL TEMPORARY table AllocMMS$OBJECTS (DDL_STATEMENT LONG) on commit preserve ROWS' ;

  EXCEPTION
           WHEN OTHERS THEN
           NULL;
END;

END AllocMMS;	/*end of package*/