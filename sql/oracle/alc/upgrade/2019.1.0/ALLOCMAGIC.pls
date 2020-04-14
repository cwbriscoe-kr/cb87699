create or replace PACKAGE BODY       Allocmagic AS


-- (not currently used) v_CRLF			CONSTANT VARCHAR2(2) := CHR(13) || CHR(10);
gv_LF			   CONSTANT VARCHAR2(1) := CHR(10);
gv_TblName         VARCHAR(65);
gv_skp_tbl         gv_TblName%TYPE;
gv_logfile         utl_file.file_type;
gv_skip_sleep_secs NUMBER := 1;
gv_sent            BOOLEAN;
-- (not currently used) v_CR			  CONSTANT VARCHAR2(1) := CHR(13);

FUNCTION get_wlkey  (
	po_src			   IN worklist.po_nbr%TYPE,
	bo_src		   	   IN worklist.bo_nbr%TYPE,
	Master_sku_src	   IN worklist.style_master_sku%TYPE,
	color_src		   IN aalwrk.color_number%TYPE,
	size_src		   IN aalwrk.size_number%TYPE,
	dimension_src   	IN aalwrk.dimension_number%TYPE,
	vendor_packid		IN worklist.vendor_pack_id%TYPE,
	qty_per_pack    	IN worklist.qty_per_pack%TYPE DEFAULT NULL,
	pack_sku        	IN worklist.pack_id%TYPE,
    receiving_src   	IN worklist.receiving_id%TYPE
	) 
	RETURN              worklist.wl_key%TYPE
	AS
	out_shape_type	     NUMBER;
	out_new_wlkey   	 worklist.wl_key%TYPE;
	
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
        out_shape_type := Allocmagicconst.const_dimension_shape;
    ELSE IF p_SizeNbr IS NOT NULL THEN
        out_shape_type := Allocmagicconst.const_size_shape;
    ELSE IF p_ColorNbr IS NOT NULL THEN
        out_shape_type := Allocmagicconst.const_color_shape;
    ELSE
        out_shape_type := Allocmagicconst.const_style_shape;
    END IF;
    END IF;
    END IF;

    RETURN out_shape_type;
    
   END get_shape_type;
	
BEGIN
	-- Initialize Shape Type with NULL
	out_shape_type := NULL;
	-- Determine the shape type first based on master_sku, color and dimension
	-- 1 is dimension
	-- 2 is size
	-- 3 is color
	-- 4 is style
	--
	out_shape_type := get_shape_type(dimension_src, size_src, color_src);
	
  BEGIN
	SELECT	/*+ first_rows(1) parallel (worklist,2) */ wl_key 
	  INTO	out_new_wlkey
	  FROM	worklist
	 WHERE	NVL(po_nbr, 0)	= NVL(po_src, 0)
	   AND	NVL(bo_nbr, 0)	= NVL(bo_src, 0)
	   AND	NVL(style_master_sku, 0) = NVL(master_sku_src, 0)
	   AND	(((vendor_packid IS NULL) AND (NVL(color_nbr, 'ColorValue') = NVL(color_src, 'ColorValue'))) OR (vendor_packid IS NOT NULL))
	   AND	shape_type	= out_shape_type
	   AND  NVL(vendor_pack_id, 'DummyValue')  = NVL (vendor_packid, 'DummyValue') -- vendor_pack is a dummy value for comparison
	   AND	NVL(receiving_id, 0) = NVL(receiving_src, 0)
	   AND	status_code <> Allocmagicconst.const_released;
  EXCEPTION
	WHEN NO_DATA_FOUND THEN
	  out_new_wlkey := 0;
  END;
  RETURN out_new_wlkey;
END get_wlkey;

--
-- This function will get the DDL for the Indexes and Keys for a given table.
--
FUNCTION RowsExistIn(p_TblName VARCHAR2,
                     p_skip_on BOOLEAN DEFAULT TRUE) 
RETURN BOOLEAN AS
   l_sqlstmt VARCHAR2(400) := 'SELECT count(*) ' || 
	                          ' FROM ' || p_TblName ||
	                          ' WHERE ROWNUM < 2' ;   
   l_cnt     NUMBER(1)     := 0;  
BEGIN
   IF p_skip_on THEN
     gv_TblName := p_TblName;
   END IF;
   
   IF gv_TblName = gv_skp_tbl 
    AND p_skip_on THEN
     gv_skp_tbl := NULL;
     RETURN FALSE;
   END IF;
   
   EXECUTE IMMEDIATE
      l_sqlstmt INTO l_cnt;
	  
   ROLLBACK;
   
   IF l_cnt > 0 THEN
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END IF;
END RowsExistIn;

--
-- This routine logs an error to the dbms_output as well as the LOG_TABLE log.
--
PROCEDURE LogError (
	p_arrStatus		IN VARCHAR2,
	p_arrMessage	IN LONG,
	p_iErrorCode	IN NUMBER	DEFAULT NULL,
	p_iRecordNbr	IN NUMBER	DEFAULT NULL,
	p_location_id     IN LOG_TABLE.location_id%TYPE DEFAULT NULL, 
	p_dept_nbr        IN LOG_TABLE.dept_nbr%TYPE DEFAULT NULL, 
	p_subdept_nbr     IN LOG_TABLE.subdept_nbr%TYPE DEFAULT NULL, 
	p_class_nbr       IN LOG_TABLE.class_nbr%TYPE DEFAULT NULL,
	p_subclass_nbr    IN LOG_TABLE.subclass_nbr%TYPE DEFAULT NULL, 
	p_master_sku      IN LOG_TABLE.master_sku%TYPE DEFAULT NULL, 
	p_color_nbr       IN LOG_TABLE.color_nbr%TYPE DEFAULT NULL, 
	p_size_nbr        IN LOG_TABLE.size_nbr%TYPE DEFAULT NULL, 
	p_dim_nbr         IN LOG_TABLE.dim_nbr%TYPE DEFAULT NULL)
IS
  lv_message VARCHAR2(3210);
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  BEGIN
    utl_file.put_line(gv_logfile,TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || ' ' || 
	                  LTRIM(p_arrMessage) || ' ' || p_arrStatus || ' ' ||
	                  p_iErrorCode || ' ' || TO_CHAR(p_iRecordNbr), FALSE);

    utl_file.fflush(gv_logfile);
  EXCEPTION
    WHEN OTHERS THEN

    DBMS_OUTPUT.ENABLE  (1120000);
	lv_message := ( TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || ' ' || 
	                      LTRIM(p_arrMessage) || ' ' || p_arrStatus 
	                      || ' ' || p_iErrorCode || ' ' || p_iRecordNbr);
	DBMS_OUTPUT.put_line( SUBSTR(lv_message,1,255) );
	IF LENGTH(lv_message) > 255 THEN
	   DBMS_OUTPUT.put_line( SUBSTR(lv_message,256,255) );
	END IF;
  END;

  INSERT INTO LOG_TABLE (status, e_message, e_code, record_nbr, 
                         location_id, dept_nbr, subdept_nbr, class_nbr, 
						 subclass_nbr, master_sku, color_nbr, size_nbr, dim_nbr)
		 VALUES	(p_arrStatus, substr(p_arrMessage,1,500), p_iErrorCode, p_iRecordNbr, 
                         p_location_id, p_dept_nbr, p_subdept_nbr, p_class_nbr, 
						 p_subclass_nbr, p_master_sku, p_color_nbr, p_size_nbr, p_dim_nbr);

	COMMIT;
END LogError;

--
-- This routine logs an error to the dbms_output as well as the LOG_TABLE log.
--
PROCEDURE LogOutput (
	p_arrStatus		IN VARCHAR2,
	p_arrMessage	IN LONG,
	p_iErrorCode	IN NUMBER	DEFAULT NULL,
	p_iRecordNbr	IN NUMBER	DEFAULT NULL,	
	p_location_id     IN LOG_TABLE.location_id%TYPE DEFAULT NULL, 
	p_dept_nbr        IN LOG_TABLE.dept_nbr%TYPE DEFAULT NULL, 
	p_subdept_nbr     IN LOG_TABLE.subdept_nbr%TYPE DEFAULT NULL, 
	p_class_nbr       IN LOG_TABLE.class_nbr%TYPE DEFAULT NULL,
	p_subclass_nbr    IN LOG_TABLE.subclass_nbr%TYPE DEFAULT NULL, 
	p_master_sku      IN LOG_TABLE.master_sku%TYPE DEFAULT NULL, 
	p_color_nbr       IN LOG_TABLE.color_nbr%TYPE DEFAULT NULL, 
	p_size_nbr        IN LOG_TABLE.size_nbr%TYPE DEFAULT NULL, 
	p_dim_nbr         IN LOG_TABLE.dim_nbr%TYPE DEFAULT NULL)
IS
  lv_message VARCHAR2(510);
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  BEGIN
    utl_file.put_line(gv_logfile,TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || ' ' || 
	                  LTRIM(p_arrMessage) || ' ' || p_arrStatus || ' ' ||
	                  p_iErrorCode || ' ' || TO_CHAR(p_iRecordNbr), FALSE);

    utl_file.fflush(gv_logfile);
  EXCEPTION
    WHEN OTHERS THEN

    DBMS_OUTPUT.ENABLE  (1120000);
	lv_message := ( TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || ' ' || 
	                      LTRIM(p_arrMessage) || ' ' || p_arrStatus 
	                      || ' ' || p_iErrorCode || ' ' || p_iRecordNbr);
	DBMS_OUTPUT.put_line( SUBSTR(lv_message,1,255) );
	IF LENGTH(lv_message) > 255 THEN
	   DBMS_OUTPUT.put_line( SUBSTR(lv_message,256,255) );
	END IF;
  END;
  
  INSERT INTO LOG_TABLE (status, e_message, e_code, record_nbr,
                         location_id, dept_nbr, subdept_nbr, class_nbr, 
						 subclass_nbr, master_sku, color_nbr, size_nbr, dim_nbr)
		 VALUES	(p_arrStatus, substr(p_arrMessage,1,500), p_iErrorCode, p_iRecordNbr, 
                         p_location_id, p_dept_nbr, p_subdept_nbr, p_class_nbr, 
						 p_subclass_nbr, p_master_sku, p_color_nbr, p_size_nbr, p_dim_nbr);


  COMMIT;
END LogOutput;

--
-- This routine return diffence between table row count and other counter
--
FUNCTION RowCountDifference (
	p_TblName IN VARCHAR2, p_count in PLS_INTEGER)
RETURN PLS_INTEGER
IS
   l_sqlstmt VARCHAR2(400) := 'SELECT count(*) ' || 
	                          ' FROM ' || p_TblName ;   
   l_cnt     PLS_INTEGER   := 0;  
BEGIN
   
   EXECUTE IMMEDIATE
      l_sqlstmt INTO l_cnt;
	  
   RETURN l_cnt - p_count;
END RowCountDifference;

--
-- This routine creates a request record for alcrequest process
--
FUNCTION SendRequest (
	p_procnm	IN VARCHAR2,
	p_parms	    IN LONG DEFAULT NULL,
	p_totproc   IN NUMBER DEFAULT 1)
RETURN BOOLEAN
IS
	lv_parms   AAL_PROC_CONTROL.PARAMETERS%TYPE;
	lv_count   NUMBER;
	lv_errored CONSTANT VARCHAR(1) :='E';
	
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  BEGIN
    SELECT COUNT(proc_nm)
      INTO lv_count
      FROM AAL_PROC_CONTROL
	 WHERE proc_nm = p_procnm
	   AND status != lv_errored;
	   
    IF lv_count < p_totproc THEN
       INSERT INTO AAL_PROC_CONTROL (proc_nm,parameters)
		 VALUES	(p_procnm,p_parms) ;
       COMMIT;
	   LogOutput('AAL_PROC_CONTROL',' SendRequest: '|| p_procnm || '(' || p_parms || ') ');
	   RETURN TRUE;
	ELSE
       RETURN FALSE;
    END IF;
	
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      INSERT INTO AAL_PROC_CONTROL (proc_nm,parameters)
		 VALUES	(p_procnm,p_parms) ;
    COMMIT;
    RETURN TRUE;
  END;
END SendRequest;

--
-- This routine creates a request record for alcrequest process
--
FUNCTION TimeConvert (
	p_hsecs	    IN NUMBER)
RETURN VARCHAR2
IS
 lv_etime VARCHAR2(11);
BEGIN
  SELECT LTRIM(TO_CHAR(TRUNC(TRUNC(p_hsecs/100)/60/60),'09')) || ':' ||
         LTRIM(TO_CHAR(TRUNC(MOD(TRUNC(p_hsecs/100),3600)/60),'09')) || ':' ||
         LTRIM(TO_CHAR(MOD(MOD(TRUNC(p_hsecs/100),3600),60),'09'))  || '.' ||
         LTRIM(TO_CHAR(MOD(p_hsecs/100,1) * 100,'09')) 
		 INTO lv_etime
         FROM dual;
		 
  RETURN lv_etime;
END TimeConvert;

--
-- PROCEDURE proc_fm_tab  - Main driver for alccommander.sh..fmproctab.sh
--
PROCEDURE proc_fm_tab(p_pid VARCHAR2) AS
 lv_TblName        gv_TblName%TYPE;
 lv_loop_count     NUMBER := 0;
 lv_hsecs          NUMBER ;
 lv_hsecs_cycle    NUMBER ;
 
BEGIN
   DBMS_OUTPUT.ENABLE  (1120000);

    gv_logfile := utl_file.fopen('ALC_LOG'
	                             ,'allocmagic_pt'
								 || p_pid
								 || '.log'
								 , 'W');
   
   lv_hsecs_cycle := dbms_utility.get_time;

	   -- If an error occurs in mms process after data was transferred will loop to check next
   -- FM_ table process
   <<cycle_loop>>
   LOOP 
  	 BEGIN
	   lv_loop_count := lv_loop_count + 1;
	   
       CASE  
	     WHEN RowsExistIn('ALR_ALOC_WKLST_RCD') THEN
         lv_hsecs := dbms_utility.get_time;
	       PROC_DB2_AALWRK( FALSE );
		     lv_TblName := gv_TblName;
	       IF ROWSEXISTIN('ANR_ALOC_NOTES_RCD') THEN
			      gv_TblName := lv_TblName || ', ' || gv_TblName;
	          PROC_DB2_AALNOT( FALSE );
		     ELSE
		        GV_TBLNAME := LV_TBLNAME;
		     END IF;
		   
	     WHEN ROWSEXISTIN('FM_AALCGR') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalcgr( FALSE );
	   
	     WHEN ROWSEXISTIN('FM_AALDPT') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aaldpt( FALSE );
	   
	     WHEN RowsExistIn('FM_AALSDP') THEN
         lv_hsecs := dbms_utility.get_time;
	       PROC_FM_AALSDP( FALSE );
	   
	     WHEN RowsExistIn('FM_AALCLS') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalcls( FALSE );
	   
       WHEN ROWSEXISTIN('FM_AALITG') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalitg( FALSE );
         
	     WHEN RowsExistIn('FM_AALSCL') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalscl( FALSE );
	   
       WHEN RowsExistIn('FM_AALCHS') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalchs( FALSE );
         
	     WHEN RowsExistIn('FM_AALSTY') THEN
         lv_hsecs := dbms_utility.get_time;
	       --gv_sent := SendRequest('Allocmagic.proc_fm_aalsty', 'FALSE' );
         proc_fm_aalsty( FALSE );
	   
	     WHEN ROWSEXISTIN('FM_AALCOL') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalcol( FALSE );
	   
	     WHEN RowsExistIn('FM_AALSIZ') THEN
         LV_HSECS := DBMS_UTILITY.GET_TIME;
	       proc_fm_aalsiz( FALSE );
	   
	     WHEN RowsExistIn('FM_AALDIM') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aaldim( FALSE );
	   
	     WHEN ROWSEXISTIN('FM_AALLOC') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalloc( FALSE );

	     WHEN ROWSEXISTIN('FM_AALMOD') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalmod( FALSE );
         
	     WHEN ROWSEXISTIN('FM_AALATR') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalatr( FALSE );
      
	     WHEN ROWSEXISTIN('FM_AALATRS') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalatrs( FALSE );
         
	     WHEN RowsExistIn('FM_AALCAL') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalcal( FALSE );
	   
	     WHEN ROWSEXISTIN('FM_AALNOT') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_fm_aalnot( FALSE );
	     
	     WHEN RowsExistIn('ANR_ALOC_NOTES_RCD') THEN
         lv_hsecs := dbms_utility.get_time;
	       proc_db2_aalnot( FALSE );
	     
	     WHEN ROWSEXISTIN('FM_AALWRK_VIEW') THEN
         lv_hsecs := dbms_utility.get_time;
	       gv_sent := SendRequest('Allocmagic.proc_fm_aalwrk2', 'FALSE' );
	   
	     WHEN RowsExistIn('FM_AALCAW') THEN
         lv_hsecs := dbms_utility.get_time;
	       PROC_FM_AALCAW( FALSE );
		     lv_loop_count := 99;
	      
	     ELSE
         lv_hsecs := dbms_utility.get_time;
	       gv_TblName := NULL;
		   
       END CASE;
	
	   IF gv_TblName IS NOT NULL THEN
		   -- DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		   --                      ' Completed processing table: ' || gv_TblName);
	       LogOutput(gv_TblName,' Completed processing table:');
	       LogOutput(NULL,' -------------------- Elapsed: ' ||
		             TimeConvert(dbms_utility.get_time - lv_hsecs) ||
					 ' ------------------');
		   COMMIT;
	   END IF;
	   
       IF lv_loop_count <= 1 THEN
	      IF gv_TblName IS NULL AND gv_skp_tbl IS NULL THEN
	         DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
	                           ' No data to process ');
		     EXIT;
	      END IF;
		  IF gv_skp_tbl IS NULL THEN
	          gv_skp_tbl := SUBSTR(gv_TblName,1,
		                        CASE (INSTR(gv_TblName,',') - 1)
                                WHEN -1 THEN LENGTH(gv_TblName) 
                                WHEN 0  THEN LENGTH(gv_TblName) 
								ELSE (INSTR(gv_TblName,',') - 1) END);
		  END IF;
	      LogOutput(gv_skp_tbl,' proc_fm_tab - sleep for ' || gv_skip_sleep_secs 
		                       || ' seconds - skip next');
		  DBMS_LOCK.sleep(gv_skip_sleep_secs);
	   ELSE
	      DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		                        ' -- Cycle complete -- Elapsed: ' || 
								 TimeConvert(dbms_utility.get_time - lv_hsecs_cycle));	
		  COMMIT;	   
	      EXIT;
	   END IF;
	   
	   
  	 EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	     LogError(gv_TblName,' proc_fm_tab - ' || SQLERRM, SQLCODE);
	     LogOutput(gv_TblName,' Completed processing table with warning:');
	       LogOutput(NULL,' -------------------- Elapsed: ' ||
		             TimeConvert(dbms_utility.get_time - lv_hsecs) ||
					 ' ------------------');
		 COMMIT;					
         IF lv_loop_count <= 1 THEN
             IF gv_skp_tbl IS NULL THEN
	              gv_skp_tbl := SUBSTR(gv_TblName,1,
		                        CASE (INSTR(gv_TblName,',') - 1)
                                WHEN -1 THEN LENGTH(gv_TblName) 
                                WHEN 0  THEN LENGTH(gv_TblName) 
								ELSE (INSTR(gv_TblName,',') - 1) END);
			 END IF;
	         LogOutput(gv_skp_tbl,' proc_fm_tab - sleep for ' || gv_skip_sleep_secs 
		                       || ' seconds - skip next');
		     DBMS_LOCK.sleep(gv_skip_sleep_secs);
		 ELSE
		     DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		                        ' -- Cycle complete with warnings -- Elapsed: ' || 
								 TimeConvert(dbms_utility.get_time - lv_hsecs_cycle));	
			 EXIT;
		 END IF;		   
		
	   WHEN OTHERS THEN
	     LogError(gv_TblName,' proc_fm_tab - ' || SQLERRM, SQLCODE);
	     LogOutput(gv_TblName,' Completed processing table with error:');
	     LogOutput(NULL,' -------------------- Elapsed: ' ||
		             TimeConvert(dbms_utility.get_time - lv_hsecs) ||
					 ' ------------------');
		 ROLLBACK;
		 
         IF lv_loop_count <= 1 THEN
             IF gv_skp_tbl IS NULL THEN
	              gv_skp_tbl := SUBSTR(gv_TblName,1,
		                        CASE (INSTR(gv_TblName,',') - 1)
                                WHEN -1 THEN LENGTH(gv_TblName) 
                                WHEN 0  THEN LENGTH(gv_TblName) 
								ELSE (INSTR(gv_TblName,',') - 1) END);
			 END IF;
	         LogOutput(gv_skp_tbl,' proc_fm_tab - sleep for ' || gv_skip_sleep_secs 
		                       || ' seconds - skip next');
		     DBMS_LOCK.sleep(gv_skip_sleep_secs);
		 ELSE
		     DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		                        ' -- Cycle complete with errors -- Elapsed: ' || 
								 TimeConvert(dbms_utility.get_time - lv_hsecs_cycle));	
			 EXIT;
		 END IF;		   
	 
  	 END;
	  
   END LOOP cycle_loop;
   
   utl_file.fflush(gv_logfile);
   COMMIT;				
   	
   utl_file.fclose_all;
   DBMS_LOCK.sleep(1);
END proc_fm_tab;

--
-- PROCEDURE proc_request  - driver for alcrequests.sh..fmrequest.sh
--  Used for long running procs to prevent clogging normal alccommander interface.
--
PROCEDURE proc_fm_request(p_pid VARCHAR2) AS
 lv_apc_row       AAL_PROC_CONTROL%ROWTYPE;
 lv_parameters    AAL_PROC_CONTROL.parameters%TYPE;
 lv_inprocess     CONSTANT AAL_PROC_CONTROL.status%TYPE := 'I';
 lv_errored       CONSTANT AAL_PROC_CONTROL.status%TYPE := 'E';
 lv_hsecs         NUMBER ;
 
 CURSOR cur_fm IS
 	   SELECT *
	     FROM AAL_PROC_CONTROL
		WHERE status = 'O'
	    ORDER BY UPDATE_TIMESTAMP
		FOR UPDATE;
BEGIN
   DBMS_OUTPUT.ENABLE  (1120000);

   gv_logfile := utl_file.fopen('ALC_LOG'
	                             ,'allocmagic_rq'
								 || p_pid
								 || '.log'
								 , 'W');

	BEGIN
	   -- Get oldest open request 
       <<cur_fm_loop>>
       FOR cur_fm_rec IN cur_fm LOOP
	      lv_apc_row := cur_fm_rec; 
		  UPDATE AAL_PROC_CONTROL
		    SET status = lv_inprocess
		  WHERE CURRENT OF cur_fm;
		  EXIT;
       END LOOP cur_fm_loop;
	   
	   -- Update status to prevent reprocessing
	   COMMIT;
	   
	   -- End if no rows
	   IF lv_apc_row.seq_id IS NULL  THEN
	      DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
	                           ' No data to process -- '
							   || p_pid );
          utl_file.fclose_all;
		  RETURN;
	   END IF;
	   
	EXCEPTION
	    WHEN OTHERS THEN
          logError(NULL,'proc_fm_request: error ' || SQLERRM, SQLCODE);
	      RETURN; 
    END;
   
    lv_hsecs := dbms_utility.get_time;
    BEGIN
    -- Execute requested procedure
      IF lv_apc_row.proc_nm IS NOT NULL THEN
		 logOutput(NULL,'proc_fm_request: Start ' || RTRIM(lv_apc_row.proc_nm)
		           || ' -- ' || p_pid);
         IF lv_apc_row.parameters IS NOT NULL THEN
	        lv_parameters := '(' || RTRIM(lv_apc_row.parameters) || ')';
	     END IF;
         EXECUTE IMMEDIATE
	        'BEGIN ' || 
			   RTRIM(lv_apc_row.proc_nm) || lv_parameters ||' ; ' ||
			'END;'; 
	  ELSE
        IF lv_apc_row.parameters IS NOT NULL THEN
		  lv_apc_row.proc_nm := SUBSTR(lv_apc_row.parameters,1,25);
		  logOutput(NULL,'proc_fm_request: Do ' || SUBSTR(lv_apc_row.parameters,1,25)
	  	           || ' -- ' || p_pid );
          EXECUTE IMMEDIATE lv_apc_row.parameters;
	    END IF;
	  END IF; 
	
	--Delete processed request		   
	  DELETE FROM AAL_PROC_CONTROL 
		 WHERE seq_id = lv_apc_row.seq_id;
		   
	  COMMIT;
	  logOutput(NULL,'proc_fm_request: End   ' || RTRIM(lv_apc_row.proc_nm)
		           || ' -- ' || p_pid );
		  
	  DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
	                       ' --Request Completed--Elapsed: ' || 
					       TimeConvert(dbms_utility.get_time - lv_hsecs) || '-- '|| p_pid );
	  
		  
	 EXCEPTION
	    WHEN OTHERS THEN
		  logError(NULL,'proc_fm_request: error ' || RTRIM(lv_apc_row.proc_nm)  || ' ' || SQLERRM, SQLCODE);
		  ROLLBACK;
		  
		  -- Update request to error status
		  UPDATE AAL_PROC_CONTROL 
		    SET status = lv_errored
		   WHERE seq_id = lv_apc_row.seq_id;
		  
	      DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
	                           ' -- Request Completed with errors --  '
							   || p_pid );
		   
	END;

    utl_file.fflush(gv_logfile);
   
    COMMIT;				
   	
    utl_file.fclose_all;
    DBMS_LOCK.sleep(1);
END proc_fm_request;

--
-- PROCEDURE proc_fm_aalcal - Execute mms aalcal process
--
PROCEDURE proc_fm_aalcal(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCAL
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALCAL;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCAL
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALCAL 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCAL', ' proc_fm_aalcal : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalcal(p_bCalledForRebuild);
END proc_fm_aalcal;

--
-- PROCEDURE proc_fm_aalcaw  - Execute mms aalcaw process
--
PROCEDURE proc_fm_aalcaw(p_bCalledForRebuild BOOLEAN) AS
        
 v_bTableTruncated	              BOOLEAN;
 
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCAW
    FOR UPDATE;
	
BEGIN
  BEGIN
  	-- To speed up removing records from log_table:
	v_bTableTruncated	:= Allocmms.TruncateTable('log_table');
   
	IF NOT v_bTableTruncated THEN
		ROLLBACK;
		LogError('FM_AALCAW', ' proc_fm_aalcaw: Not able to truncate table ''log_table''.');
	END IF;
	
  EXCEPTION
    WHEN OTHERS THEN
      NULL;
  END;
  
  BEGIN
    gv_sent := SendRequest('Allocmagic2.proc_fm_aalrst_archive');
    LogOutput (null,'proc_fm_aalcaw: Waits 30 minutes  ');
    DBMS_LOCK.sleep(1800);
	--Wait for proc_fm_aalsty_stage2 process and hold next process 
    LOGOUTPUT (NULL,'proc_fm_aalcaw: Waits for proc_fm_aalsty_stage2');
    LOCK TABLE aalsty IN EXCLUSIVE MODE; 
    LogOutput (null,'proc_fm_aalcaw: Begin process ');
    DELETE AALCAW;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCAW
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALCAW 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCAW', ' proc_fm_aalcaw : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  
  COMMIT;
  
  Allocmms.proc_aalcaw(p_bCalledForRebuild);
  
  BEGIN
      EXECUTE IMMEDIATE 'alter table aam.stage_dimension logging';
  END;
  BEGIN
      EXECUTE IMMEDIATE 'alter table aam.stage_subclass logging';
  END;
  BEGIN
      EXECUTE IMMEDIATE 'alter table aam.stage_v_class logging';
  END;
  
  COMMIT;
  proc_db2_ALR_archive;
  proc_db2_results_archive;
END proc_fm_aalcaw;

--
-- PROCEDURE proc_fm_aalcgr  - Execute mms aalcgr process
--
PROCEDURE proc_fm_aalcgr(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCGR
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALCGR;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCGR
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALCGR 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCGR', ' proc_fm_aalcgr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalcgr(p_bCalledForRebuild);
END proc_fm_aalcgr;

--
-- PROCEDURE proc_fm_aalcls  - Execute mms aalcls process
--
PROCEDURE proc_fm_aalcls(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCLS
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALCLS;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCLS
       VALUES cur_fm_rec;
	  DELETE FROM FM_AALCLS 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCLS', ' procfm_aalcls : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalcls(p_bCalledForRebuild);
END proc_fm_aalcls;

--
-- PROCEDURE proc_fm_aalcol  - Execute mms aalcol process
--
PROCEDURE proc_fm_aalcol(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCOL
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALCOL;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCOL
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALCOL 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCOL', ' procfm_aalcol : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalcol(p_bCalledForRebuild);
END proc_fm_aalcol;

--
-- PROCEDURE proc_fm_aaldim  - Execute mms aaldim process
--
PROCEDURE proc_fm_aaldim(p_bCalledForRebuild BOOLEAN) AS

 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALDIM
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALDIM;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALDIM
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALDIM 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALDIM', ' procfm_aalaph : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT; 
  
  Allocmms.proc_aaldim(p_bCalledForRebuild);
END proc_fm_aaldim;

--
-- PROCEDURE proc_fm_aaldpt  - Execute mms aaldpt process
--
PROCEDURE proc_fm_aaldpt(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALDPT
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALDPT;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALDPT
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALDPT 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALDPT', ' proc_fm_aaldpt : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aaldpt(p_bCalledForRebuild);
END proc_fm_aaldpt;

--
-- PROCEDURE proc_fm_aalloc  - Execute mms aalloc process
--
PROCEDURE proc_fm_aalloc(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALLOC
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALLOC;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
	  IF cur_fm_rec.operation_code < '3' THEN
	   BEGIN
        SELECT Z_OPEN_04,
            Z_OPEN_05, Z_OPEN_06, Z_OPEN_07, Z_OPEN_08,
            Z_OPEN_09, Z_OPEN_10, Z_OPEN_11, Z_OPEN_12,
            Z_OPEN_13, Z_OPEN_14, Z_OPEN_15, Z_OPEN_16,
            Z_OPEN_17, Z_OPEN_18, Z_OPEN_19, Z_OPEN_20, 
            Z_OPEN_21, Z_OPEN_22, Z_OPEN_23, Z_OPEN_24, 
            Z_OPEN_25, Z_OPEN_26, Z_OPEN_27, Z_OPEN_28, 
            Z_OPEN_29, Z_OPEN_30, Z_OPEN_31, Z_OPEN_32, 
            Z_OPEN_33, Z_OPEN_34, Z_OPEN_35, Z_OPEN_36, 
            Z_OPEN_37, Z_OPEN_38, Z_OPEN_39, Z_OPEN_40
          INTO
           cur_fm_rec.Z_OPEN_04, cur_fm_rec.Z_OPEN_05, cur_fm_rec.Z_OPEN_06, 
           cur_fm_rec.Z_OPEN_07, cur_fm_rec.Z_OPEN_08, cur_fm_rec.Z_OPEN_09, 
           cur_fm_rec.Z_OPEN_10, cur_fm_rec.Z_OPEN_11, cur_fm_rec.Z_OPEN_12, 
           cur_fm_rec.Z_OPEN_13, cur_fm_rec.Z_OPEN_14, cur_fm_rec.Z_OPEN_15, 
           cur_fm_rec.Z_OPEN_16, cur_fm_rec.Z_OPEN_17, cur_fm_rec.Z_OPEN_18, 
           cur_fm_rec.Z_OPEN_19, cur_fm_rec.Z_OPEN_20, cur_fm_rec.Z_OPEN_21, 
           cur_fm_rec.Z_OPEN_22, cur_fm_rec.Z_OPEN_23, cur_fm_rec.Z_OPEN_24, 
           cur_fm_rec.Z_OPEN_25, cur_fm_rec.Z_OPEN_26, cur_fm_rec.Z_OPEN_27, 
           cur_fm_rec.Z_OPEN_28, cur_fm_rec.Z_OPEN_29, cur_fm_rec.Z_OPEN_30, 
           cur_fm_rec.Z_OPEN_31, cur_fm_rec.Z_OPEN_32, cur_fm_rec.Z_OPEN_33, 
           cur_fm_rec.Z_OPEN_34, cur_fm_rec.Z_OPEN_35, cur_fm_rec.Z_OPEN_36, 
           cur_fm_rec.Z_OPEN_37, cur_fm_rec.Z_OPEN_38, cur_fm_rec.Z_OPEN_39, 
           cur_fm_rec.Z_OPEN_40
         FROM LOCATIONS
         WHERE location_id = cur_fm_rec.location_number;
       EXCEPTION
         WHEN OTHERS THEN
		   NULL;
	   END;
	  END IF;
    
    cur_fm_rec.Z_OPEN_01 := RTRIM(cur_fm_rec.Z_OPEN_01);
    cur_fm_rec.Z_OPEN_02 := RTRIM(cur_fm_rec.Z_OPEN_02);
    cur_fm_rec.Z_OPEN_03 := RTRIM(cur_fm_rec.Z_OPEN_03);
    
      INSERT INTO AALLOC
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALLOC 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
  
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALLOC', ' proc_fm_aalloc : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalloc(p_bCalledForRebuild);
  COMMIT;
END proc_fm_aalloc;

--
-- PROCEDURE proc_fm_aalmod  - Execute mms aalmod process
--
PROCEDURE proc_fm_aalmod(p_bCalledForRebuild BOOLEAN) AS
BEGIN

  EXECUTE IMMEDIATE 'TRUNCATE TABLE AAM.AALMOD REUSE STORAGE';
  
  BEGIN
    INSERT INTO AALMOD
    SELECT /*+ PARALLEL */ fm_aalmod.*, null, null, null, null, null FROM FM_AALMOD;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALMOD', ' proc_fm_aalmod : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
    RAISE;
  END;
  COMMIT;
  
  EXECUTE IMMEDIATE 'TRUNCATE TABLE AAMFM.FM_AALMOD REUSE STORAGE';
  
  Allocmms.proc_aalmod(p_bCalledForRebuild);
  
END proc_fm_aalmod;

--
-- PROCEDURE proc_fm_aalatr  - Execute mms aalatr process
--
PROCEDURE proc_fm_aalatr(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm1 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 1
     ORDER BY ATTR_CODE
    FOR UPDATE;

 CURSOR cur_fm2 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 2
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
 CURSOR cur_fm3 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 3
     ORDER BY ATTR_CODE
    FOR UPDATE;
  
 CURSOR cur_fm4 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 4
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
 CURSOR cur_fm5 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 5
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
 CURSOR cur_fm6 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 6
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
 CURSOR cur_fm7 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 7
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
 CURSOR cur_fm8 IS
 	SELECT *
      FROM FM_AALATR
     WHERE ATTR_NBR = 8
     ORDER BY ATTR_CODE
    FOR UPDATE;
    
BEGIN

  BEGIN
    DELETE AALAT1;
    <<cur_fm_loop1>>
    FOR cur_fm_rec IN cur_fm1 LOOP
      INSERT INTO AALAT1
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm1;
    END LOOP cur_fm_loop1;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-1', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;
  
  BEGIN
    DELETE AALAT2;
    <<cur_fm_loop2>>
    FOR cur_fm_rec IN cur_fm2 LOOP
      INSERT INTO AALAT2
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm2;
    END LOOP cur_fm_loop2;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-2', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT3;
    <<cur_fm_loop3>>
    FOR cur_fm_rec IN cur_fm3 LOOP
      INSERT INTO AALAT3
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm3;
    END LOOP cur_fm_loop3;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-3', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT4;
    <<cur_fm_loop4>>
    FOR cur_fm_rec IN cur_fm4 LOOP
      INSERT INTO AALAT4
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm4;
    END LOOP cur_fm_loop4;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-4', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT5;
    <<cur_fm_loop5>>
    FOR cur_fm_rec IN cur_fm5 LOOP
      INSERT INTO AALAT5
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm5;
    END LOOP cur_fm_loop5;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-5', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT6;
    <<cur_fm_loop6>>
    FOR cur_fm_rec IN cur_fm6 LOOP
      INSERT INTO AALAT6
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm6;
    END LOOP cur_fm_loop6;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-6', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT7;
    <<cur_fm_loop7>>
    FOR cur_fm_rec IN cur_fm7 LOOP
      INSERT INTO AALAT7
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm7;
    END LOOP cur_fm_loop7;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-7', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;

  BEGIN
    DELETE AALAT8;
    <<cur_fm_loop8>>
    FOR cur_fm_rec IN cur_fm8 LOOP
      INSERT INTO AALAT8
	   VALUES ('1', rtrim(cur_fm_rec.attr_code), rtrim(cur_fm_rec.attr_desc));
	  DELETE FROM FM_AALATR
       WHERE CURRENT OF cur_fm8;
    END LOOP cur_fm_loop8;
  EXCEPTION
    WHEN OTHERS THEN 
	  LogError('FM_AALATR-8', ' proc_fm_aalatr : Error occurred transferring data-'|| SQLERRM,SQLCODE);
    ROLLBACK;  
  END;
  COMMIT;
  
  Allocmms.proc_aalat1(p_bCalledForRebuild);
  Allocmms.proc_aalat2(p_bCalledForRebuild);
  Allocmms.proc_aalat3(p_bCalledForRebuild);
  Allocmms.proc_aalat4(p_bCalledForRebuild);
  Allocmms.proc_aalat5(p_bCalledForRebuild);
  Allocmms.proc_aalat6(p_bCalledForRebuild);
  Allocmms.proc_aalat7(p_bCalledForRebuild);
  Allocmms.proc_aalat8(p_bCalledForRebuild);
  
END proc_fm_aalatr;

--
-- PROCEDURE proc_fm_aalatrs  - Execute mms aalatrs process
--
PROCEDURE proc_fm_aalatrs(p_bCalledForRebuild BOOLEAN) AS
  DOW VARCHAR2(1);
  lv_count NUMBER := 0;
  BEGIN
    
    --Wait for proc_fm_aalsty_stage2 process and hold next process 
    LOGOUTPUT (NULL,'proc_fm_aalatrs: waiting for proc_fm_aalsty_stage2');
    LOCK TABLE aalsty IN EXCLUSIVE MODE; 
    LogOutput (NULL,'proc_fm_aalatrs: begin process ');

    --Audit stage_dimension against fm_aalatrs_archive and insert any 
    --mismatched SKU's into fm_aalatrs to correct
    BEGIN
      INSERT /*+ PARALLEL */ INTO FM_AALATRS
      WITH SKUS AS (
      SELECT DISTINCT A.SKU_NBR
        FROM STAGE_DIMENSION S
            ,FM_AALATRS_ARCHIVE A
       WHERE S.STYLE_MASTER_SKU = A.SKU_NBR
         AND (NVL(S.ATTR_1_CODE,' ') != NVL(A.ATTR_1_CODE,' ')
          OR  NVL(S.ATTR_2_CODE,' ') != NVL(A.ATTR_2_CODE,' ')
          OR  NVL(S.ATTR_3_CODE,' ') != NVL(A.ATTR_3_CODE,' ')
          OR  NVL(S.ATTR_4_CODE,' ') != NVL(A.ATTR_4_CODE,' ')
          OR  NVL(S.ATTR_5_CODE,' ') != NVL(A.ATTR_5_CODE,' ')
          OR  NVL(S.ATTR_6_CODE,' ') != NVL(A.ATTR_6_CODE,' ')
          OR  NVL(S.ATTR_7_CODE,' ') != NVL(A.ATTR_7_CODE,' ')
          OR  NVL(S.ATTR_8_CODE,' ') != NVL(A.ATTR_8_CODE,' '))
         AND NOT EXISTS (
              SELECT NULL
                FROM FM_AALATRS F
               WHERE F.SKU_NBR = A.SKU_NBR)
      )
      SELECT A.*
        FROM FM_AALATRS_ARCHIVE A
            ,SKUS S
       WHERE A.SKU_NBR = S.SKU_NBR
       ;      
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in audit - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    lv_count := SQL%ROWCOUNT;
    LOGOUTPUT(NULL,'proc_fm_aalatrs: audit skus added: '||lv_count);
    
    COMMIT;
 
    --Gather statistics to vastly improve performance since last auto 
    --statistics may have been ran when table was empty
    BEGIN
      DBMS_STATS.GATHER_TABLE_STATS('AAMFM','FM_AALATRS');
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in gather table stats - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    BEGIN
      DBMS_STATS.GATHER_INDEX_STATS('AAMFM','FM_AALATRS_IDX');
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in gather index stats - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    BEGIN
      UPDATE /*+ PARALLEL */ STAGE_DIMENSION S
         SET (ATTR_1_CODE
             ,ATTR_2_CODE
             ,ATTR_3_CODE
             ,ATTR_4_CODE
             ,ATTR_5_CODE
             ,ATTR_6_CODE
             ,ATTR_7_CODE
             ,ATTR_8_CODE) = (
       SELECT RTRIM(ATTR_1_CODE)
             ,RTRIM(ATTR_2_CODE)
             ,RTRIM(ATTR_3_CODE)
             ,RTRIM(ATTR_4_CODE)
             ,RTRIM(ATTR_5_CODE)
             ,RTRIM(ATTR_6_CODE)
             ,RTRIM(ATTR_7_CODE)
             ,RTRIM(ATTR_8_CODE)
         FROM FM_AALATRS A
        WHERE A.SKU_NBR = S.SKU_NBR
       )
        WHERE EXISTS (
        SELECT NULL
          FROM FM_AALATRS A
         WHERE A.SKU_NBR = S.SKU_NBR
       );
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in update - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    lv_count := SQL%ROWCOUNT;
    LOGOUTPUT(NULL,'proc_fm_aalatrs: stage_dimension rows updated: '||lv_count);
  
    COMMIT;
    
    --MERGE FM_AALATRS INTO ARCHIVE IN CASE NEEDED AT SOME POINT IN TIME
    BEGIN
      MERGE INTO FM_AALATRS_ARCHIVE A USING
      (SELECT * FROM FM_AALATRS
      ) B ON (A.SKU_NBR = B.SKU_NBR)
      WHEN MATCHED THEN
        UPDATE
        SET A.ATTR_1_CODE = RTRIM(B.ATTR_1_CODE) ,
          A.ATTR_2_CODE   = RTRIM(B.ATTR_2_CODE) ,
          A.ATTR_3_CODE   = RTRIM(B.ATTR_3_CODE) ,
          A.ATTR_4_CODE   = RTRIM(B.ATTR_4_CODE) ,
          A.ATTR_5_CODE   = RTRIM(B.ATTR_5_CODE) ,
          A.ATTR_6_CODE   = RTRIM(B.ATTR_6_CODE) ,
          A.ATTR_7_CODE   = RTRIM(B.ATTR_7_CODE) ,
          A.ATTR_8_CODE   = RTRIM(B.ATTR_8_CODE) ,
          A.ATTR_9_CODE   = RTRIM(B.ATTR_9_CODE) ,
          A.ATTR_10_CODE  = RTRIM(B.ATTR_10_CODE) ,
          A.ATTR_11_CODE  = RTRIM(B.ATTR_11_CODE) ,
          A.ATTR_12_CODE  = RTRIM(B.ATTR_12_CODE) 
      WHEN NOT MATCHED THEN
        INSERT VALUES
          (
            B.SKU_NBR ,
            RTRIM(B.ATTR_1_CODE) ,
            RTRIM(B.ATTR_2_CODE) ,
            RTRIM(B.ATTR_3_CODE) ,
            RTRIM(B.ATTR_4_CODE) ,
            RTRIM(B.ATTR_5_CODE) ,
            RTRIM(B.ATTR_6_CODE) ,
            RTRIM(B.ATTR_7_CODE) ,
            RTRIM(B.ATTR_8_CODE) ,
            RTRIM(B.ATTR_9_CODE) ,
            RTRIM(B.ATTR_10_CODE) ,
            RTRIM(B.ATTR_11_CODE) ,
            RTRIM(B.ATTR_12_CODE)
          ) ;
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in merge - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    COMMIT;
    
    BEGIN
      DELETE FM_AALATRS;
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in delete - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    lv_count := SQL%ROWCOUNT;
    LOGOUTPUT(NULL,'proc_fm_aalatrs: fm_aalatrs rows processed: '||lv_count);
    
    COMMIT;
    
    --get day of week so that we do not rebuild stage subclass and class on the
    --day we do the weekly roll (proc_do_roll)
    BEGIN
      SELECT to_char(SYSDATE, 'd') into DOW FROM dual;
    EXCEPTION
      WHEN OTHERS THEN
        LogError('FM_AALATRS', ' proc_fm_aalatrs : Error occurred in get DOW - '|| SQLERRM,SQLCODE);
        ROLLBACK;
        RAISE;
    END;
    
    --Don't run on Sunday
    IF DOW != '1' THEN
      LOGOUTPUT(NULL,'proc_fm_aalatrs: reloading stage_subclass');
      ALLOCMMS.REBUILDSTAGESUBCLASS;
      LOGOUTPUT(NULL,'proc_fm_aalatrs: reloading stage_class');
      ALLOCMMS.REBUILDSTAGECLASS;
    END IF;
    
END PROC_FM_AALATRS;

--
-- PROCEDURE proc_db2_aalnot  - Execute mms aalnot process from db2 table
--
PROCEDURE proc_db2_aalnot(p_bCalledForRebuild BOOLEAN) AS
 lv_start_ts       TIMESTAMP;
 lv_start_tschar   VARCHAR(26);
 lv_count          NUMBER := 0;
 lv_del_count      NUMBER := 0;
       
BEGIN
  lv_start_ts := SYSTIMESTAMP - 04/86400;
--  lv_start_ts := SYSTIMESTAMP + 3/24 - 04/86400;
  lv_start_tschar :=TO_CHAR(lv_start_ts,'YYYY-MM-DD-HH24.MI.SS.FF6');
  BEGIN
    DELETE AALNOT;

    INSERT INTO AALNOT
	  SELECT  OPR_CD      AS OPERATION_CODE
		   , RTRIM(POR_DTB_NO) AS PO_DST_NUMBER
		   , BAK_ORD_NO AS BO_NUMBER
		   , NTE_SEQ_NO AS NOTE_SEQUENCE
		   , SUBSTR(POR_NTE_TX,1,50) AS PO_NOTE   
      FROM ANR_ALOC_NOTES_RCD
     WHERE TO_TIMESTAMP(TO_CHAR(ROW_UPD_TS,'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS') < TO_TIMESTAMP(lv_start_ts);
 	  lv_count := lv_count + SQL%ROWCOUNT;
	  
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('ANR_ALOC_NOTES_RCD@DB2MAGIC', ' proc_db2_aalnot : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  COMMIT;
  LogOutput('AALNOT', ' proc_db2_aalnot: insert count: ' || lv_count );
  
  BEGIN
    DELETE FROM ANR_ALOC_NOTES_RCD
-- CEB 2016-08-08 START
--     WHERE ROW_UPD_TS < LV_START_TSCHAR;
     WHERE TO_CHAR(ROW_UPD_TS,'YYYY-MM-DD-HH24.MI.SS')  < LV_START_TSCHAR;
-- CEB 2016-08-08 END	   
	   
 	lv_del_count := lv_del_count + SQL%ROWCOUNT;
   
    IF lv_del_count != lv_count THEN
       RAISE_APPLICATION_ERROR(-20000, 'Delete count/Insert count did not match');
    END IF;
    
  EXCEPTION
    WHEN OTHERS THEN       
	  LogError('ANR_ALOC_NOTES_RCD@DB2MAGIC', ' proc_db2_aalnot: Error occurred on delete: ' || lv_del_count 
	                                         || ' ' || SQLERRM,SQLCODE);
      ROLLBACK;  
      DELETE AALNOT;
	  lv_del_count := SQL%ROWCOUNT;
	  COMMIT;
	  RETURN;
  END;
  
  COMMIT;
  LogOutput('ANR_ALOC_NOTES_RCD@DB2MAGIC', ' proc_db2_aalnot: delete count: ' || lv_del_count );

  Allocmms.proc_aalnot(p_bCalledForRebuild);
END proc_db2_aalnot;

--
-- PROCEDURE proc_fm_aalnot  - Execute mms aalnot process
--
PROCEDURE proc_fm_aalnot(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALNOT
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALNOT;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALNOT
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALNOT 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALNOT', ' procfm_aalnot : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalnot(p_bCalledForRebuild);
END proc_fm_aalnot;

--
-- PROCEDURE proc_fm_aalitg  - Execute mms aalitg process
--
PROCEDURE proc_fm_aalitg(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALITG
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALITG;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALITG
       VALUES cur_fm_rec;
	  DELETE FROM FM_AALITG
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALITG', ' proc_fm_aalitg : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalitg(p_bCalledForRebuild);
END proc_fm_aalitg;

--
-- PROCEDURE proc_fm_aalscl  - Execute mms aalscl process
--
PROCEDURE proc_fm_aalscl(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALSCL
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALSCL;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALSCL
       VALUES cur_fm_rec;
	  DELETE FROM FM_AALSCL 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALSCL', ' procfm_aalscl : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalscl(p_bCalledForRebuild);
END proc_fm_aalscl;

--
-- PROCEDURE proc_fm_aalchs  - Execute mms aalchs process
--
PROCEDURE proc_fm_aalchs(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALCHS
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALCHS;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALCHS
       VALUES cur_fm_rec;
	  DELETE FROM FM_AALCHS
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALCHS', ' proc_fm_aalchs : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalchs(p_bCalledForRebuild);
END proc_fm_aalchs;

--
-- PROCEDURE proc_fm_aalsdp  - Execute mms aalsdp process
--
PROCEDURE proc_fm_aalsdp(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALSDP
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALSDP;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALSDP
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALSDP 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALSDP', ' procfm_aalsdp : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalsdp(p_bCalledForRebuild);
END proc_fm_aalsdp;

--
-- PROCEDURE proc_fm_aalsiz  - Execute mms aalsiz process
--
PROCEDURE proc_fm_aalsiz(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALSIZ
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALSIZ;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALSIZ
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALSIZ 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALSIZ', ' procfm_aalsiz : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  
  COMMIT;
  
  Allocmms.proc_aalsiz(p_bCalledForRebuild);
END proc_fm_aalsiz;

/*
--
-- PROCEDURE proc_fm_aalsty - Execute mms aalsty process
--
PROCEDURE proc_fm_aalsty(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALSTY
--	  WHERE ROWNUM <= 50000
    FOR UPDATE;
	
BEGIN
		LogOutput (null,'proc_fm_aalsty: Waiting for sty_stage process ');
		--Wait for sty process
        LOCK TABLE aalsty IN EXCLUSIVE MODE; 
		LogOutput (null,'proc_fm_aalsty: Begin Process ');

  BEGIN
 
    DELETE AALSTY;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALSTY
       VALUES cur_fm_rec;
	  IF cur_fm_rec.operation_code IN ('1','2') THEN
	     cur_fm_rec.sku_number:= NVL(cur_fm_rec.sku_number, 0);
	     DELETE FROM LIST_SKU
		  WHERE	style_master_sku = TO_CHAR(cur_fm_rec.sku_number);
	  END IF;
    IF cur_fm_rec.operation_code = '3' THEN
	     cur_fm_rec.sku_number:= NVL(cur_fm_rec.sku_number, 0);
	     DELETE FROM STAGE_DIMENSION
		    WHERE	style_master_sku = TO_CHAR(cur_fm_rec.sku_number);
	  END IF;
	  DELETE FROM FM_AALSTY 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALSTY', ' proc_fm_aalsty: Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  COMMIT;
  Allocmms.proc_aalsty(p_bCalledForRebuild); 
END proc_fm_aalsty;
*/

--
-- PROCEDURE proc_fm_aalsty - Execute mms aalsty process
--
PROCEDURE proc_fm_aalsty(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALSTY
--	  WHERE ROWNUM <= 50000
    FOR UPDATE;
	
BEGIN
		LogOutput (null,'proc_fm_aalsty: Waiting for sty_stage process ');
		--Wait for sty process
        LOCK TABLE aalsty IN EXCLUSIVE MODE; 
		LogOutput (null,'proc_fm_aalsty: Begin Process ');

  BEGIN
 
    DELETE AALSTY;
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
      INSERT INTO AALSTY
       VALUES cur_fm_rec;
	  IF cur_fm_rec.operation_code IN ('1','2') THEN
	     cur_fm_rec.sku_number:= NVL(cur_fm_rec.sku_number, 0);
	     DELETE FROM LIST_SKU
		  WHERE	style_master_sku = TRIM(TO_CHAR(cur_fm_rec.SKU_NUMBER,'00000000'));
	  END IF;
    IF cur_fm_rec.operation_code = '3' THEN
	     cur_fm_rec.sku_number:= NVL(cur_fm_rec.sku_number, 0);
	     DELETE FROM STAGE_DIMENSION
		    WHERE	style_master_sku = TRIM(TO_CHAR(cur_fm_rec.SKU_NUMBER,'00000000'));
	  END IF;
	  DELETE FROM FM_AALSTY 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALSTY', ' proc_fm_aalsty: Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
  END;
  COMMIT;
  Allocmms.proc_aalsty(p_bCalledForRebuild); 
END proc_fm_aalsty;

--
-- PROCEDURE proc_db2_aalwrk  - Execute mms aalwrk process
--
PROCEDURE proc_db2_aalwrk(p_bCalledForRebuild BOOLEAN) AS

 lv_start_ts       TIMESTAMP;
 lv_start_tschar   VARCHAR(26);
 testvar AALWRK.TROUBLE_CODE%TYPE;
 lv_count     NUMBER := 0;
 lv_del_count NUMBER := 0;
 
BEGIN
  --lv_start_ts := SYSTIMESTAMP + 03/24 - 10/86400;
  lv_start_ts := SYSTIMESTAMP - 10/86400;
  lv_start_tschar :=TO_CHAR(lv_start_ts,'YYYY-MM-DD-HH24.MI.SS.FF6');
  BEGIN
    LogOutput(null, ' proc_db2_aalwrk: timestamp cutoff: ' || lv_start_tschar );
    DBMS_LOCK.sleep(3);
    DELETE AALWRK;
   
   -- Insert data from ALR to AALWRK based on current oracle time -10 seconds
    INSERT INTO AALWRK     
	   SELECT OPR_CD            AS OPERATION_CODE        
         ,MRC_SRC_CD            AS MERCHANDISE_SOURCE       
         ,RTRIM(POR_DTB_NO)     AS PO_DST_NUMBER            
         ,BAK_ORD_NO            AS BO_NUMBER                
		 ,CASE SUBSTR(CLX_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE CLX_NO END      AS COLOR_NUMBER               
--         ,CLX_NO                AS COLOR_NUMBER             
         ,CLX_NAM_TX            AS COLOR_NAME  
		 ,CASE SUBSTR(SIZ_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE SIZ_NO END      AS SIZE_NUMBER               
--         ,SIZ_NO                AS SIZE_NUMBER              
         ,SIZ_NAM_TX            AS SIZE_NAME                
		 ,CASE SUBSTR(DIM_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE DIM_NO  END     AS DIMENSION_NUMBER       
--         ,DIM_NO                AS DIMENSION_NUMBER         
         ,DIM_NAM_TX            AS DIMENSION_NAME           
         ,LIN_SEQ_NO            AS LINE_SEQUENCE            
         ,EPT_RCT_DT            AS EXP_RECEIPT_DATE         
         ,POR_VND_NO            AS PURCH_VENDOR_NUMBER      
         ,POR_VND_NAM_TX        AS PURCH_VENDOR_NAME        
         --,RTRIM(STY_MAS_SKU_NO) AS STYLE_MASTER_SKU   
         ,TRIM(TO_CHAR(STY_MAS_SKU_NO,'00000000')) AS STYLE_MASTER_SKU
         ,RTRIM(PDT_NAM_TX)     AS PRODUCT_NAME             
         ,AVL_PAK_QY            AS AVAILABLE_PACKS          
         ,ONN_ORD_PAK_QY        AS ON_ORDER_PACKS           
		 ,CASE PER_PAK_QY
		   WHEN 0 THEN NULL
		   ELSE PER_PAK_QY END  AS QUANTITY_PER_PACK       
--         ,PER_PAK_QY            AS QUANTITY_PER_PACK        
         ,DFL_WHS_NO            AS DEFAULT_WAREHOUSE        
         ,RCV_NO                AS RECEIVER_NUMBER          
         ,RCT_DT                AS RECEIPT_DATE             
         ,DPT_NO                AS DEPARTMENT_NUMBER        
         ,RTRIM(DPT_NAM_TX)     AS DEPARTMENT_NAME          
         ,SUB_DPT_NO            AS SUBDEPARTMENT_NUMBER     
         ,RTRIM(SUB_DPT_NAM_TX) AS SUBDEPARTMENT_NAME       
         ,CLS_CD                AS CLASS_NUMBER             
         ,RTRIM(CLS_DSC_TX)     AS CLASS_NAME  
         ,ITG_CD                AS ITEM_GROUP_NUMBER
         ,RTRIM(ITG_DSC_TX)     AS ITEM_GROUP_NAME
         ,SBC_CD                AS SUBCLASS_NUMBER          
         ,RTRIM(SBC_DSC_TX)     AS SUBCLASS_NAME   
         ,CHC_CD                AS CHOICE_NUMBER
         ,RTRIM(CHC_DSC_TX)     AS CHOICE_NAME
         ,COO_GRP_CD            AS COORD_GROUP              
         ,COO_GRP_DSC_TX        AS COORD_GROUP_NAME         
         ,RTL_PRC_AM            AS RETAIL_PRICE             
         ,SUBSTR(SHP_CMT_TX,1,72)              AS SHIPPING_COMMENTS        
		     ,SUBSTR(POR_NTE_002_TX,1,50)          AS PO_NOTE_1
         ,SUBSTR(POR_NTE_002_TX,1,50)          AS PO_NOTE_2                
         ,SUBSTR(POR_NTE_003_TX,1,50)          AS PO_NOTE_3                
         ,USR_FLD_001_TX        AS Z_OPEN_01            
         ,USR_FLD_002_TX        AS Z_OPEN_02            
         ,USR_FLD_003_TX        AS Z_OPEN_03            
         ,USR_FLD_004_TX        AS Z_OPEN_04            
         ,USR_FLD_005_TX        AS Z_OPEN_05            
         ,USR_FLD_006_TX        AS Z_OPEN_06            
         ,USR_FLD_007_TX        AS Z_OPEN_07  
-- CEB 2011-07-07 BEGIN
         ,(SELECT QTY
             FROM COMP_SKU_QTY CP
            WHERE CP.STYLE_MASTER_SKU = RTRIM(STY_MAS_SKU_NO))      AS Z_OPEN_08
         ,(COALESCE((
           SELECT ON_HAND_CURR
             FROM FM_STORE_OH OH
            WHERE OH.STYLE_MASTER_SKU = RTRIM(STY_MAS_SKU_NO)), 0)) AS Z_OPEN_09
-- CEB 2011-07-07 END             
         ,USR_FLD_010_TX        AS Z_OPEN_10            
         ,USR_FLD_011_TX        AS Z_OPEN_11            
         ,USR_FLD_012_TX        AS Z_OPEN_12            
         ,USR_FLD_013_TX        AS Z_OPEN_13            
         ,USR_FLD_014_TX        AS Z_OPEN_14            
         ,USR_FLD_015_TX        AS Z_OPEN_15            
         ,RTRIM(PAK_SKU_NO)     AS PACK_SKU             
         ,CASE SUBSTR(VND_PAK_QY,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE VND_PAK_QY END                     AS VENDOR_PACK            
         ,CASE SUBSTR(ERR_CND_CD,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE ERR_CND_CD END                     AS TROUBLE_CODE
        ,CASE TO_CHAR(POR_AD_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(POR_AD_DT,'YYYYMMDD') END  AS PO_AD_DATE
         ,CASE SUBSTR(OPN_TOO_BUY_PID_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(OPN_TOO_BUY_PID_NO) END  AS OTB_PERIOD
         ,CASE SUBSTR(OPN_TOO_BUY_WEK_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(OPN_TOO_BUY_WEK_NO) END  AS OTB_WEEK
         ,CASE TO_CHAR(SHP_BY_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(SHP_BY_DT,'YYYYMMDD') END  AS SHIP_DATE
		 ,CASE SUBSTR(DTN_WHS_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(DTN_WHS_NO) END          AS DEST_WHSE  
         ,CASE SUBSTR(PMY_VND_FLW_CD,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE PMY_VND_FLW_CD END                 AS PRIM_VEND_FLOWCODE
         ,CASE TO_CHAR(TRNS_AD_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(TRNS_AD_DT,'YYYYMMDD') END AS TRANS_AD_DATE
         ,CASE TO_CHAR(INN_STO_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(INN_STO_DT,'YYYYMMDD') END AS IN_STORE_DATE
         ,CASE REP_FL
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE REP_FL  END                        AS REPLEN_FLAG
         ,CASE SKU_STU_CD
		   WHEN '' THEN NULL
		   WHEN '  ' THEN NULL
		   ELSE SKU_STU_CD  END                    AS SKU_STATUS
      ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
      ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
      ,TRIM(TO_CHAR(STY_MAS_SKU_NO,'00000000')) AS MODEL_NAME
      FROM ALR_ALOC_WKLST_RCD
	   WHERE TO_TIMESTAMP(TO_CHAR(RCD_UPD_TS,'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS') < TO_TIMESTAMP(LV_START_TS);
      lv_count := sql%ROWCOUNT;
	  
	  INSERT INTO DB2_ALR_ARCHIVE
	   SELECT * FROM ALR_ALOC_WKLST_RCD
	   WHERE TO_TIMESTAMP(TO_CHAR(RCD_UPD_TS,'YYYYMMDDHH24MISS'),'YYYYMMDDHH24MISS') < TO_TIMESTAMP(lv_start_ts);
	   	   
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('AALWRK', ' proc_db2_aalwrk : Error occurred transferring data: ' || SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  COMMIT;
  LogOutput('AALWRK', ' proc_db2_aalwrk: insert count: ' || lv_count );
	
  
  BEGIN
    DELETE FROM ALR_ALOC_WKLST_RCD
-- CEB 2016-08-08 BEGIN
--   WHERE RCD_UPD_TS < LV_START_TSCHAR;
     WHERE TO_CHAR(RCD_UPD_TS,'YYYY-MM-DD-HH24.MI.SS')  < LV_START_TSCHAR;
-- CEB 2016-08-08 END	   
 	lv_del_count := lv_del_count + SQL%ROWCOUNT;
   
    IF lv_del_count != lv_count THEN
       RAISE_APPLICATION_ERROR(-20000, 'Delete count/Insert count did not match');
    END IF;
    
  EXCEPTION
    WHEN OTHERS THEN       
	    LOGERROR('ALR_ALOC_WKLST_RCD@DB2MAGIC', ' proc_db2_aalwrk: Error occurred on delete: ' || LV_DEL_COUNT || ' ' || SQLERRM,SQLCODE);
      LogError('ALR_ALOC_WKLST_RCD@DB2MAGIC', ' proc_db2_aalwrk: Timestamp: ' || lv_start_tschar);
      ROLLBACK;  
      DELETE AALWRK;
	  lv_del_count := SQL%ROWCOUNT;
	  COMMIT;
	  RETURN;
  END;
  COMMIT;
  LogOutput('ALR_ALOC_WKLST_RCD@DB2MAGIC', ' proc_db2_aalwrk: delete count: ' || lv_del_count );
  
  -- Copy data for post update routine
  BEGIN
      DELETE FM_AALWRKQ;
	  INSERT INTO FM_AALWRKQ
	   SELECT * FROM AALWRK;
  EXCEPTION
    WHEN OTHERS THEN
	  LogError('FM_AALWRKQ', ' proc_db2_aalwrk : Error occurred transferring data: ' || SQLERRM,SQLCODE);
  END;
  
  Allocmms.proc_aalwrk(p_bCalledForRebuild);
  proc_fm_aalwrk_post;
END proc_db2_aalwrk;

--
-- Create db2 ALR interface table archive
--
PROCEDURE proc_db2_alr_archive AS

lv_days_limit  NUMBER := 45;

CURSOR drop_cur IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('DB2_ALR_arc000000000000') 
      AND UPPER('DB2_ALR_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') ||'000000';
	  
BEGIN
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur LOOP
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
 	EXECUTE IMMEDIATE
	   'CREATE TABLE DB2_ALR_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM DB2_ALR_ARCHIVE WHERE 1=0';
	EXECUTE IMMEDIATE
	   'ALTER TABLE DB2_ALR_ARCHIVE ' || gv_LF || 
	   ' EXCHANGE PARTITION DB2_ALR_ARCHIVE_01' || gv_LF ||
	   ' WITH TABLE DB2_ALR_ARC ';
	EXECUTE IMMEDIATE
	   'RENAME DB2_ALR_ARC TO DB2_ALR_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
EXCEPTION
  WHEN OTHERS THEN
    logError('DB2_ALR', ' proc_db2_alr_archive : Error during alr archiving-'|| SQLERRM,SQLCODE);
END proc_db2_alr_archive;

--
-- PROCEDURE proc_db2_aalwrk  - Execute mms aalwrk process
--
PROCEDURE proc_db2_aalwrk2(p_bCalledForRebuild BOOLEAN) AS

 lv_start_ts       TIMESTAMP;
 lv_start_tschar   VARCHAR(26);
 testvar AALWRK.TROUBLE_CODE%TYPE;
        	
BEGIN
  lv_start_ts := SYSTIMESTAMP - 10/86400;
--  lv_start_ts := SYSTIMESTAMP + 03/24 - 10/86400;
  lv_start_tschar :=TO_CHAR(lv_start_ts,'YYYY-MM-DD-HH24.MI.SS.FF6');
  BEGIN
    DELETE AALWRK;
    DELETE FM_AALWRKQ;
   
    INSERT INTO FM_AALWRK     
	   SELECT OPR_CD            AS OPERATION_CODE        
         ,MRC_SRC_CD            AS MERCHANDISE_SOURCE       
         ,RTRIM(POR_DTB_NO)     AS PO_DST_NUMBER            
         ,BAK_ORD_NO            AS BO_NUMBER                
		 ,CASE SUBSTR(CLX_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE CLX_NO END      AS COLOR_NUMBER                           
         ,CLX_NAM_TX            AS COLOR_NAME  
		 ,CASE SUBSTR(SIZ_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE SIZ_NO END      AS SIZE_NUMBER                           
         ,SIZ_NAM_TX            AS SIZE_NAME                
		 ,CASE SUBSTR(DIM_NO,1,1)
		   WHEN ' ' THEN NULL
		   WHEN '0' THEN NULL
		   ELSE DIM_NO  END     AS DIMENSION_NUMBER            
         ,DIM_NAM_TX            AS DIMENSION_NAME           
         ,LIN_SEQ_NO            AS LINE_SEQUENCE            
         ,EPT_RCT_DT            AS EXP_RECEIPT_DATE         
         ,POR_VND_NO            AS PURCH_VENDOR_NUMBER      
         ,POR_VND_NAM_TX        AS PURCH_VENDOR_NAME        
         --,RTRIM(STY_MAS_SKU_NO) AS STYLE_MASTER_SKU    
         ,TRIM(TO_CHAR(STY_MAS_SKU_NO,'00000000')) AS STYLE_MASTER_SKU
         ,RTRIM(PDT_NAM_TX)     AS PRODUCT_NAME             
         ,AVL_PAK_QY            AS AVAILABLE_PACKS          
         ,ONN_ORD_PAK_QY        AS ON_ORDER_PACKS           
		 ,CASE PER_PAK_QY
		   WHEN 0 THEN NULL
		   ELSE PER_PAK_QY END  AS QUANTITY_PER_PACK              
         ,DFL_WHS_NO            AS DEFAULT_WAREHOUSE        
         ,RCV_NO                AS RECEIVER_NUMBER          
         ,RCT_DT                AS RECEIPT_DATE             
         ,DPT_NO                AS DEPARTMENT_NUMBER        
         ,RTRIM(DPT_NAM_TX)     AS DEPARTMENT_NAME          
         ,SUB_DPT_NO            AS SUBDEPARTMENT_NUMBER     
         ,RTRIM(SUB_DPT_NAM_TX) AS SUBDEPARTMENT_NAME       
         ,CLS_CD                AS CLASS_NUMBER             
         ,RTRIM(CLS_DSC_TX)     AS CLASS_NAME  
         ,ITG_CD                AS ITEM_GROUP_NUMBER
         ,RTRIM(ITG_DSC_TX)     AS ITEM_GROUP_NAME
         ,SBC_CD                AS SUBCLASS_NUMBER          
         ,RTRIM(SBC_DSC_TX)     AS SUBCLASS_NAME 
         ,CHC_CD                AS CHOICE_NUMBER
         ,RTRIM(CHC_DSC_TX)     AS CHOICE_NAME
         ,COO_GRP_CD            AS COORD_GROUP              
         ,COO_GRP_DSC_TX        AS COORD_GROUP_NAME         
         ,RTL_PRC_AM            AS RETAIL_PRICE             
         ,SUBSTR(SHP_CMT_TX,1,72)            AS SHIPPING_COMMENTS        
		     ,SUBSTR(POR_NTE_002_TX,1,50)          AS PO_NOTE_1
         ,SUBSTR(POR_NTE_002_TX,1,50)          AS PO_NOTE_2                
         ,SUBSTR(POR_NTE_003_TX,1,50)          AS PO_NOTE_3                
         ,USR_FLD_001_TX        AS Z_OPEN_01            
         ,USR_FLD_002_TX        AS Z_OPEN_02            
         ,USR_FLD_003_TX        AS Z_OPEN_03            
         ,USR_FLD_004_TX        AS Z_OPEN_04            
         ,USR_FLD_005_TX        AS Z_OPEN_05            
         ,USR_FLD_006_TX        AS Z_OPEN_06            
         ,USR_FLD_007_TX        AS Z_OPEN_07            
         ,USR_FLD_008_TX        AS Z_OPEN_08            
         ,USR_FLD_009_TX        AS Z_OPEN_09            
         ,USR_FLD_010_TX        AS Z_OPEN_10            
         ,USR_FLD_011_TX        AS Z_OPEN_11            
         ,USR_FLD_012_TX        AS Z_OPEN_12            
         ,USR_FLD_013_TX        AS Z_OPEN_13            
         ,USR_FLD_014_TX        AS Z_OPEN_14            
         ,USR_FLD_015_TX        AS Z_OPEN_15            
         ,RTRIM(PAK_SKU_NO)     AS PACK_SKU             
         ,CASE SUBSTR(VND_PAK_QY,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE VND_PAK_QY END                     AS VENDOR_PACK            
         ,CASE SUBSTR(ERR_CND_CD,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE ERR_CND_CD END                     AS TROUBLE_CODE
         ,CASE TO_CHAR(POR_AD_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(POR_AD_DT,'YYYYMMDD') END  AS PO_AD_DATE
         ,CASE SUBSTR(OPN_TOO_BUY_PID_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(OPN_TOO_BUY_PID_NO) END  AS OTB_PERIOD
         ,CASE SUBSTR(OPN_TOO_BUY_WEK_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(OPN_TOO_BUY_WEK_NO) END  AS OTB_WEEK
         ,CASE TO_CHAR(SHP_BY_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(SHP_BY_DT,'YYYYMMDD') END  AS SHIP_DATE
          --,TO_CHAR(SHP_BY_DT,'YYYYMMDD')           AS SHIP_DATE
		 ,CASE SUBSTR(DTN_WHS_NO,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE TO_NUMBER(DTN_WHS_NO) END          AS DEST_WHSE  
         ,CASE SUBSTR(PMY_VND_FLW_CD,1,1)
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE PMY_VND_FLW_CD END                 AS PRIM_VEND_FLOWCODE
         ,CASE TO_CHAR(TRNS_AD_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(TRNS_AD_DT,'YYYYMMDD') END AS TRANS_AD_DATE
         --,TO_CHAR(TRNS_AD_DT,'YYYYMMDD')           AS TRANS_AD_DATE
         ,CASE TO_CHAR(INN_STO_DT,'YYYYMMDD')
		   WHEN ' ' THEN NULL
		   WHEN '00010101' THEN NULL
		   ELSE TO_CHAR(INN_STO_DT,'YYYYMMDD') END AS IN_STORE_DATE
         --,TO_CHAR(INN_STO_DT,'YYYYMMDD')           AS IN_STORE_DATE
         ,CASE REP_FL
		   WHEN '' THEN NULL
		   WHEN ' ' THEN NULL
		   ELSE REP_FL  END                        AS REPLEN_FLAG
         ,CASE SKU_STU_CD
		   WHEN '' THEN NULL
		   WHEN '  ' THEN NULL
		   ELSE SKU_STU_CD  END                    AS SKU_STATUS
      ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
      ,NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
      ,TRIM(TO_CHAR(STY_MAS_SKU_NO,'00000000')) AS MODEL_NAME
      FROM ALR_ALOC_WKLST_RCD
	   WHERE RCD_UPD_TS < TO_TIMESTAMP(lv_start_ts);
      
	  INSERT INTO FM_AALWRKQ
	   SELECT * FROM FM_AALWRK;
	   
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('ALR_ALOC_WKLST_RCD@DB2MAGIC', ' procdb2_aalwrk : Error occurred transferring data: ' || SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  COMMIT;
  
  BEGIN
    DELETE FROM ALR_ALOC_WKLST_RCD
       WHERE RCD_UPD_TS < lv_start_tschar;
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('ALR_ALOC_WKLST_RCD@DB2MAGIC', ' procdb2_aalwrk : Error occurred transferring data: ' || SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;

  COMMIT;
END proc_db2_aalwrk2;

--
-- PROCEDURE proc_fm_aalwrk  - Execute mms aalwrk process
--
PROCEDURE proc_fm_aalwrk(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALWRK
    FOR UPDATE;
	
BEGIN
  BEGIN
    DELETE AALWRK;
	
    DELETE FM_AALWRKQ;
	COMMIT;
	
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
	  IF SUBSTR(cur_fm_rec.trouble_code,1,1) = ' ' THEN
	     cur_fm_rec.trouble_code := NULL;
	  END IF;
  	  IF cur_fm_rec.quantity_per_pack = 0 THEN
  	     cur_fm_rec.quantity_per_pack := NULL;
	  END IF;
  	  IF SUBSTR(cur_fm_rec.vendor_pack,1,1) = ' ' THEN
  	     cur_fm_rec.vendor_pack := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.color_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.color_number,1,1) = ' ' THEN
	     cur_fm_rec.color_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.size_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.size_number,1,1) = ' ' THEN
	     cur_fm_rec.size_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.dimension_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.dimension_number,1,1) = ' ' THEN
	     cur_fm_rec.dimension_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.po_ad_date,1,1) = ' ' THEN
	     cur_fm_rec.po_ad_date := NULL;
	  END IF;	  
	  IF SUBSTR(cur_fm_rec.ship_date,1,1) = ' ' THEN
	     cur_fm_rec.ship_date := NULL;
	  END IF;	  
	  IF SUBSTR(cur_fm_rec.trans_ad_date,1,1) = ' ' THEN 
	     cur_fm_rec.trans_ad_date := NULL;
	  END IF;
	  	  IF SUBSTR(cur_fm_rec.in_store_date,1,1) = ' ' THEN
	     cur_fm_rec.in_store_date := NULL;
	  END IF;
    
    cur_fm_rec.STYLE_MASTER_SKU := TRIM(TO_CHAR(TO_NUMBER(TRIM(cur_fm_rec.STYLE_MASTER_SKU)),'00000000'));
    
    cur_fm_rec.PACK_SKU := RTRIM(cur_fm_rec.PACK_SKU);
    
      INSERT INTO AALWRK
	   VALUES cur_fm_rec;
      INSERT INTO FM_AALWRKQ
	   VALUES cur_fm_rec;
	  DELETE FROM FM_AALWRK 
       WHERE CURRENT OF cur_fm;
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALWRK', ' procfm_aalwrk : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK; 
	  RAISE; 
  END;
  
  Allocmms.proc_aalwrk(p_bCalledForRebuild);
  proc_fm_aalwrk_post;
END proc_fm_aalwrk;

--
-- PROCEDURE proc_fm_aalwrk2  - Execute mms aalwrk process
--
PROCEDURE proc_fm_aalwrk2(p_bCalledForRebuild BOOLEAN) AS
        
 CURSOR cur_fm IS
  SELECT  fm.OPERATION_CODE        
         ,fm.MERCHANDISE_SOURCE    
         ,fm.PO_DST_NUMBER         
         ,coalesce(wl.BO_NBR,fm.BO_NUMBER) BO_NUMBER             
         ,fm.COLOR_NUMBER          
         ,fm.COLOR_NAME            
         ,fm.SIZE_NUMBER           
         ,fm.SIZE_NAME             
         ,fm.DIMENSION_NUMBER      
         ,fm.DIMENSION_NAME        
         ,fm.LINE_SEQUENCE         
         ,fm.EXP_RECEIPT_DATE      
         ,fm.PURCH_VENDOR_NUMBER   
         ,fm.PURCH_VENDOR_NAME     
         ,FM.STYLE_MASTER_SKU      
         ,rtrim(fm.PRODUCT_NAME) as product_name      
         ,fm.AVAILABLE_PACKS       
         ,fm.ON_ORDER_PACKS        
         ,fm.QUANTITY_PER_PACK     
         ,fm.DEFAULT_WAREHOUSE     
         ,fm.RECEIVER_NUMBER       
         ,fm.RECEIPT_DATE          
         ,FM.DEPARTMENT_NUMBER     
         ,rtrim(fm.DEPARTMENT_NAME) as department_name
         ,FM.SUBDEPARTMENT_NUMBER  
         ,rtrim(fm.SUBDEPARTMENT_NAME) as subdepartment_name 
         ,FM.CLASS_NUMBER          
         ,rtrim(fm.CLASS_NAME) as class_name        
         ,FM.ITEM_GROUP_NUMBER     
         ,rtrim(fm.ITEM_GROUP_NAME) as item_group_name       
         ,FM.SUBCLASS_NUMBER       
         ,rtrim(fm.SUBCLASS_NAME) as subclass_name         
         ,FM.CHOICE_NUMBER         
         ,rtrim(fm.CHOICE_NAME) as choice_name           
         ,fm.COORD_GROUP           
         ,fm.COORD_GROUP_NAME      
         ,fm.RETAIL_PRICE          
         ,fm.SHIPPING_COMMENTS     
         ,fm.PO_NOTE_1             
         ,fm.PO_NOTE_2             
         ,fm.PO_NOTE_3             
         ,fm.Z_OPEN_01             
         ,fm.Z_OPEN_02             
         ,fm.Z_OPEN_03             
         ,fm.Z_OPEN_04             
         ,fm.Z_OPEN_05             
         ,fm.Z_OPEN_06             
         ,fm.Z_OPEN_07             
         ,fm.Z_OPEN_08             
         ,fm.Z_OPEN_09             
         ,fm.Z_OPEN_10             
         ,fm.Z_OPEN_11             
         ,fm.Z_OPEN_12             
         ,fm.Z_OPEN_13             
         ,fm.Z_OPEN_14             
         ,fm.Z_OPEN_15             
         ,fm.PACK_SKU              
         ,fm.VENDOR_PACK           
         ,fm.TROUBLE_CODE          
         ,fm.PO_AD_DATE            
         ,fm.OTB_PERIOD            
         ,fm.OTB_WEEK              
         ,fm.SHIP_DATE             
         ,fm.DEST_WHSE             
         ,fm.PRIM_VEND_FLOWCODE    
         ,fm.TRANS_AD_DATE         
         ,fm.IN_STORE_DATE         
         ,fm.REPLEN_FLAG           
         ,fm.SKU_STATUS         
         ,NVL(wl.wl_key,0) wl_key 
         ,NVL(wl.cnt,0) cnt,ROWIDTOCHAR(fm.ROWID) row_id   
	  FROM  (SELECT w.* ,COUNT(*) OVER (PARTITION BY po_nbr,bo_nbr,style_master_sku,
					       shape_type,vendor_pack_id,receiving_id,status_code ) cnt 
	           FROM worklist w) wl,
			(SELECT operation_code, 
			 merchandise_source, 
			 RTRIM(po_dst_number)   po_dst_number,
			 bo_number, 
			 CASE SUBSTR(color_number,1,1)
			   WHEN ' ' THEN NULL
			   WHEN '0' THEN NULL
			  ELSE color_number END color_number, 
			 color_name, 
			 CASE SUBSTR(size_number,1,1)
			   WHEN ' ' THEN NULL
			   WHEN '0' THEN NULL
			  ELSE size_number END  size_number,
			 size_name, 
			 CASE SUBSTR(dimension_number,1,1)
			   WHEN ' ' THEN NULL
			   WHEN '0' THEN NULL
			  ELSE dimension_number END dimension_number, 
			 dimension_name,line_sequence, 
			 exp_receipt_date, purch_vendor_number, purch_vendor_name, 
			 TRIM(TO_CHAR(TO_NUMBER(TRIM(style_master_sku)),'00000000')) as style_master_sku, product_name, available_packs, 
			 on_order_packs, quantity_per_pack, default_warehouse, 
			 receiver_number, receipt_date, department_number, 
			 department_name, subdepartment_number, subdepartment_name, 
			 class_number, class_name, item_group_number, item_group_name, subclass_number, 
			 subclass_name, choice_number, choice_name, coord_group, coord_group_name, 
			 retail_price, shipping_comments, 
			 po_note_1, po_note_2, po_note_3, 
			 z_open_01, z_open_02, z_open_03, z_open_04, z_open_05, 
			 z_open_06, z_open_07, z_open_08, z_open_09, z_open_10, 
			 z_open_11, z_open_12, z_open_13, z_open_14, z_open_15, 
			 pack_sku, 
			 CASE SUBSTR(vendor_pack,1,1)
			    WHEN ' ' THEN NULL
				ELSE vendor_pack END vendor_pack, 
			 trouble_code, po_ad_date, otb_period, 
			 otb_week, ship_date, dest_whse, prim_vend_flowcode, 
			 trans_ad_date, in_store_date, replen_flag, sku_status
               FROM FM_AALWRK) fm
	 WHERE	NVL(po_nbr(+), 0)	= NVL(fm.po_dst_number, 0)
	   --AND	NVL(bo_nbr(+), 0)	= NVL(fm.bo_number, 0)
	   AND	NVL(wl.style_master_sku(+), 0) = NVL(fm.style_master_sku, 0)
	   AND	(((fm.vendor_pack IS NULL) 
            AND (NVL(wl.color_nbr, 'ColorValue') = NVL(fm.color_number, 'ColorValue'))) 
          OR (fm.vendor_pack IS NOT NULL))
	   AND	wl.shape_type(+) = (CASE nvl2(fm.dimension_number,'*',NULL)
                          WHEN '*' THEN Allocmagicconst.const_dimension_shape
                         ELSE CASE nvl2(fm.size_number,'*',NULL)
                          WHEN '*' THEN Allocmagicconst.const_size_shape
                         ELSE CASE nvl2(color_number,'*',NULL)
                          WHEN '*'  THEN Allocmagicconst.const_color_shape
                         ELSE Allocmagicconst.const_style_shape END END END)
	   AND  NVL(wl.vendor_pack_id(+), 'DummyValue')  = NVL (fm.vendor_pack, 'DummyValue') -- vendor_pack is a dummy value for comparison
	   AND	NVL(wl.receiving_id(+), 0) = NVL(fm.receiver_number, 0)
	   AND	wl.status_code(+) <> Allocmagicconst.const_released;
	   
	lv_rowcount NUMBER := 0 ;
	lv_rowadds  NUMBER := 0 ;

BEGIN
  BEGIN
    DELETE AALWRK2;
	
--    DELETE FM_AALWRK2Q;
	COMMIT;
	
   LogOutput (null,'proc_fm_aalwrk2: Hold aalwrk2 table ');
   --Wait for wrk2 processs 
   LOCK TABLE aalwrk2 IN EXCLUSIVE MODE; 
   LogOutput (null,'proc_fm_aalwrk2: Begin Process ');
  
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
	  IF SUBSTR(cur_fm_rec.trouble_code,1,1) = ' ' THEN
	     cur_fm_rec.trouble_code := NULL;
	  END IF;
  	  IF cur_fm_rec.quantity_per_pack = 0 THEN
  	     cur_fm_rec.quantity_per_pack := NULL;
	  END IF;
  	  IF SUBSTR(cur_fm_rec.vendor_pack,1,1) = ' ' THEN
  	     cur_fm_rec.vendor_pack := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.color_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.color_number,1,1) = ' ' THEN
	     cur_fm_rec.color_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.size_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.size_number,1,1) = ' ' THEN
	     cur_fm_rec.size_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.dimension_number,1,1) = '0' 
	   OR SUBSTR(cur_fm_rec.dimension_number,1,1) = ' ' THEN
	     cur_fm_rec.dimension_number := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.po_ad_date,1,1) = ' ' THEN
	     cur_fm_rec.po_ad_date := NULL;
	  END IF;	  
	  IF SUBSTR(cur_fm_rec.ship_date,1,1) = ' ' THEN
	     cur_fm_rec.ship_date := NULL;
	  END IF;	  
	  IF SUBSTR(cur_fm_rec.trans_ad_date,1,1) = ' ' THEN 
	     cur_fm_rec.trans_ad_date := NULL;
	  END IF;
	  IF SUBSTR(cur_fm_rec.in_store_date,1,1) = ' ' THEN
	     cur_fm_rec.in_store_date := NULL;
	  END IF;

    cur_fm_rec.PACK_SKU := RTRIM(cur_fm_rec.PACK_SKU);
    
      INSERT INTO AALWRK2
	   VALUES cur_fm_rec;
	   
	  INSERT /*+append */ INTO FM_AALWRK_ARCHIVE
		VALUES(cur_fm_rec.OPERATION_CODE, cur_fm_rec.MERCHANDISE_SOURCE, cur_fm_rec.PO_DST_NUMBER, 
		   cur_fm_rec.BO_NUMBER, cur_fm_rec.COLOR_NUMBER, cur_fm_rec.COLOR_NAME, 
		   cur_fm_rec.SIZE_NUMBER, cur_fm_rec.SIZE_NAME, cur_fm_rec.DIMENSION_NUMBER,
		   cur_fm_rec.DIMENSION_NAME, cur_fm_rec.LINE_SEQUENCE, cur_fm_rec.EXP_RECEIPT_DATE,
		   cur_fm_rec.PURCH_VENDOR_NUMBER, cur_fm_rec.PURCH_VENDOR_NAME, cur_fm_rec.STYLE_MASTER_SKU,
		   cur_fm_rec.PRODUCT_NAME, cur_fm_rec.AVAILABLE_PACKS, cur_fm_rec.ON_ORDER_PACKS,
		   cur_fm_rec.QUANTITY_PER_PACK, cur_fm_rec.DEFAULT_WAREHOUSE, cur_fm_rec.RECEIVER_NUMBER,
		   cur_fm_rec.RECEIPT_DATE, cur_fm_rec.DEPARTMENT_NUMBER, cur_fm_rec.DEPARTMENT_NAME,
		   cur_fm_rec.SUBDEPARTMENT_NUMBER, cur_fm_rec.SUBDEPARTMENT_NAME, cur_fm_rec.CLASS_NUMBER,
		   cur_fm_rec.CLASS_NAME, cur_fm_rec.ITEM_GROUP_NUMBER, cur_fm_rec.ITEM_GROUP_NAME, cur_fm_rec.SUBCLASS_NUMBER, cur_fm_rec.SUBCLASS_NAME,
		   cur_fm_rec.CHOICE_NUMBER, cur_fm_rec.CHOICE_NAME, cur_fm_rec.COORD_GROUP, cur_fm_rec.COORD_GROUP_NAME,cur_fm_rec.RETAIL_PRICE, 
		   cur_fm_rec.SHIPPING_COMMENTS,cur_fm_rec.PO_NOTE_1, cur_fm_rec.PO_NOTE_2, 
		   cur_fm_rec.PO_NOTE_3, cur_fm_rec.Z_OPEN_01, cur_fm_rec.Z_OPEN_02, cur_fm_rec.Z_OPEN_03,
		   cur_fm_rec.Z_OPEN_04, cur_fm_rec.Z_OPEN_05, cur_fm_rec.Z_OPEN_06,cur_fm_rec.Z_OPEN_07,
		   cur_fm_rec.Z_OPEN_08, cur_fm_rec.Z_OPEN_09, cur_fm_rec.Z_OPEN_10, cur_fm_rec.Z_OPEN_11, 
		   cur_fm_rec.Z_OPEN_12, cur_fm_rec.Z_OPEN_13, cur_fm_rec.Z_OPEN_14, cur_fm_rec.Z_OPEN_15,
		   cur_fm_rec.PACK_SKU, cur_fm_rec.VENDOR_PACK, cur_fm_rec.TROUBLE_CODE,
		   cur_fm_rec.PO_AD_DATE, cur_fm_rec.OTB_PERIOD, cur_fm_rec.OTB_WEEK,
		   cur_fm_rec.SHIP_DATE, cur_fm_rec.DEST_WHSE, cur_fm_rec.PRIM_VEND_FLOWCODE,
		   cur_fm_rec.TRANS_AD_DATE, cur_fm_rec.IN_STORE_DATE, cur_fm_rec.REPLEN_FLAG,
		   cur_fm_rec.SKU_STATUS, TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6'),NULL);
		   	  
	   DELETE FROM FM_AALWRK
       WHERE ROWID = cur_fm_rec.row_id;
	   
	   lv_rowcount := lv_rowcount + 1;
	   IF cur_fm_rec.wl_key = 0 
	    AND cur_fm_rec.operation_code < 3 THEN
	     lv_rowadds := lv_rowadds + 1;
	   END IF;
    END LOOP cur_fm_loop;

	IF lv_rowcount < 1 THEN
	  LogError('FM_AALWRK', ' proc_fm_aalwrk2 : No Data to process');
	  RETURN;
	END IF;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALWRK', ' proc_fm_aalwrk2 : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK; 
	  RAISE; 
  END;
  
  LogOutput('FM_AALWRK', ' proc_fm_aalwrk2 : Records processing: '|| lv_rowcount);
  LogOutput('FM_AALWRK', ' proc_fm_aalwrk2 : Records with new keys: '|| lv_rowadds);
  Allocmms.proc_aalwrk2(p_bCalledForRebuild);
  PROC_FM_AALWRK_POST2;  
END proc_fm_aalwrk2;

--
-- Create reserve worklist interim table archive
--
PROCEDURE proc_fm_aalwrk2_archive AS


lv_days_limit  INTEGER := 5;

CURSOR drop_cur IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('fm_aalwrk_arc000000000000') 
      AND UPPER('fm_aalwrk_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';
	  
BEGIN
  
  BEGIN
    LogOutput('FM_AALWRK', ' proc_fm_aalwrk2_archive: Creating archive ' );

 	EXECUTE IMMEDIATE
	   'CREATE TABLE FM_AALWRK_ARC' || gv_LF || 
	   ' NOLOGGING TABLESPACE AAMDATA AS ' ||
	   ' SELECT * FROM FM_AALWRK_ARCHIVE WHERE 1=0';
	EXECUTE IMMEDIATE
	   'ALTER TABLE FM_AALWRK_ARCHIVE ' || gv_LF || 
	   ' EXCHANGE PARTITION FM_AALWRK_ARCHIVE_01' || gv_LF ||
	   ' WITH TABLE FM_AALWRK_ARC ';
	EXECUTE IMMEDIATE
	   'RENAME FM_AALWRK_ARC TO FM_AALWRK_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur LOOP
       LogOutput('FM_AALWRK', ' proc_fm_aalwrk2_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
  EXCEPTION
    WHEN OTHERS THEN
      logError('FM_AALWRK', ' proc_fm_aalwrk2_archive : Error during archiving-'|| SQLERRM,SQLCODE);
  END;		
END proc_fm_aalwrk2_archive;

--
-- Create archives from reserve worklist process...Update worklist hierarchy
--
PROCEDURE proc_fm_wl_cleanup AS
 lv_count NUMBER := 0;

BEGIN
   LogOutput (null,'proc_fm_wl_cleanup: Waiting for wrk2 process ');
   DBMS_LOCK.sleep(300);
   --Wait for wrk2 process and hold wrk2 process 
   LOCK TABLE aalwrk2 IN EXCLUSIVE MODE; 
   LogOutput (null,'proc_fm_wl_cleanup: Begin Process ');
  
   -- Copy daily transactions
   proc_fm_aalwrk2_archive;
   BEGIN 
     -- Synch worklist with List_Sku hierarchy when necessary
	 proc_fm_prdsync_worklist;
	 COMMIT;
	 -- copy worklist and related tables
     proc_fm_worklist_archive;
     
   --CEB 2014-05-05 commenting out next line because we think that the PurgeResult utility
   --mysteriously deleted the whole worklist
	 --gv_sent := SendRequest('AALResultsUtils.PurgeResults');
     
     -- Reset stuck status 60 worklist lines to 30 approved if results exist
     UPDATE worklist wl
       SET status_code = 30, status_desc = 'Approved'
     WHERE status_timestamp < CURRENT_DATE - .04166 -- 1 hour back
       AND status_code = 60
       AND EXISTS 
       (SELECT NULL FROM results_detail rd
         WHERE rd.allocation_nbr=wl.alloc_nbr
           AND rd.wl_key=wl.wl_key);
       
     lv_count := sql%ROWCOUNT;

     -- Reset stuck status 60 worklist lines to 10 available if results missing
     UPDATE worklist wl
       SET status_code = 10, status_desc = 'Available'
     WHERE status_timestamp < CURRENT_DATE - .04166 -- 1 hour back
       AND status_code = 60
       AND NOT EXISTS 
       (SELECT NULL FROM results_detail rd
         WHERE rd.allocation_nbr=wl.alloc_nbr
           AND rd.wl_key=wl.wl_key);
       
     lv_count := lv_count + sql%ROWCOUNT;
     			
     COMMIT;

     LogOutput('WORKLIST', ' proc_fm_wl_cleanup: Status 60 rows processed: ' || lv_count);
       
    EXCEPTION
	 WHEN OTHERS THEN
	   RAISE;
   END;
   COMMIT;
END proc_fm_wl_cleanup;

--
-- Cleanup Actual_Format table
--
PROCEDURE proc_fm_actual_format_cleanup AS

BEGIN

  LogOutput (null,'proc_fm_actual_format_cleanup: Begin Process ');
  
   BEGIN 
     -- Synch worklist with List_Sku hierarchy when necessary
	 DELETE from ACTUAL_FORMAT
     WHERE not exists
     (SELECT null FROM results_header WHERE alloc_nbr=allocation_nbr);
	 COMMIT;

   EXCEPTION
	 WHEN OTHERS THEN
	   RAISE;
   END;
   COMMIT; 
END PROC_FM_ACTUAL_FORMAT_CLEANUP;

--
-- Create worklist, pack_style, results_detail tables' archives
--
PROCEDURE proc_fm_worklist_archive AS

lv_days_limit  INTEGER := 5;

CURSOR drop_cur_wl IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('worklist_arc000000000000') 
      AND UPPER('worklist_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';
	  
CURSOR drop_cur_ps IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('pack_style_arc000000000000') 
      AND UPPER('pack_style_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';

CURSOR drop_cur_rd IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('results_detail_arc000000000000') 
      AND UPPER('results_detail_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';
	  
CURSOR drop_cur_rh IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('results_header_arc000000000000') 
      AND UPPER('results_header_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';
	  
CURSOR drop_cur_rl IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('results_loc_arc000000000000') 
      AND UPPER('results_loc_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') || '000000';
	  
BEGIN
  BEGIN
    LogOutput('WORKLIST', ' proc_fm_worklist_archive: Creating archive ' );
 	EXECUTE IMMEDIATE
	   'CREATE TABLE WORKLIST_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM WORKLIST';
	EXECUTE IMMEDIATE
	   'RENAME WORKLIST_ARC TO WORKLIST_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur_wl LOOP
       LogOutput('WORKLIST', ' proc_fm_worklist_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
  EXCEPTION
    WHEN OTHERS THEN
      logError('WORKLIST', ' proc_fm_worklist_archive: Error during archiving-'|| SQLERRM,SQLCODE);
	  RAISE;
  END;
  
  BEGIN
    LogOutput('PACK_STYLE', ' proc_fm_worklist_archive: Creating archive ' );
	EXECUTE IMMEDIATE
	   'CREATE TABLE PACK_STYLE_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM PACK_STYLE';
	EXECUTE IMMEDIATE
	   'RENAME PACK_STYLE_ARC TO PACK_STYLE_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur_ps LOOP
       LogOutput('PACK_STYLE', ' proc_fm_worklist_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
   EXCEPTION
    WHEN OTHERS THEN
      logError('PACK_STYLE', ' proc_fm_worklist_archive: Error during archiving-'|| SQLERRM,SQLCODE);
	  RAISE;
  END;	

  BEGIN
    LogOutput('RESULTS_DETAIL', ' proc_fm_worklist_archive: Creating archive ' );
 	EXECUTE IMMEDIATE
	   'CREATE TABLE RESULTS_DETAIL_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM RESULTS_DETAIL';
	EXECUTE IMMEDIATE
	   'RENAME RESULTS_DETAIL_ARC TO RESULTS_DETAIL_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur_rd LOOP
       LogOutput('RESULTS_DETAIL', ' proc_fm_worklist_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
  EXCEPTION
    WHEN OTHERS THEN
      logError('RESULTS_DETAIL', ' proc_fm_worklist_archive: Error during archiving-'|| SQLERRM,SQLCODE);
	  RAISE;
  END;	
  
  BEGIN
    LogOutput('RESULTS_HEADER', ' proc_fm_worklist_archive: Creating archive ' );
 	EXECUTE IMMEDIATE
	   'CREATE TABLE RESULTS_HEADER_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT ' ||
     ' ALLOCATION_NBR,' ||
     ' SAVED_NAME,' ||
     ' SAVED_DESC,' ||
     ' USER_ID,' ||
     ' AAM_CREATEUSER,' ||
     ' GLOBAL_FLAG,' ||
     ' PLANNING_TIMECODE,' ||
     ' CREATEUSER,' ||
     ' CREATEDATE,' ||
     ' UPDATEUSER,' ||
     ' UPDATEDATE,' ||
     ' TO_LOB(ENV_INFORMATION) AS ENV_INFORMATION' ||
     ' FROM RESULTS_HEADER';
	EXECUTE IMMEDIATE
	   'RENAME RESULTS_HEADER_ARC TO RESULTS_HEADER_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur_rh LOOP
       LogOutput('RESULTS_HEADER', ' proc_fm_worklist_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
  EXCEPTION
    WHEN OTHERS THEN
      logError('RESULTS_HEADER', ' proc_fm_worklist_archive: Error during archiving-'|| SQLERRM,SQLCODE);
	  RAISE;
  END;	
  
  BEGIN
    LogOutput('RESULTS_LOCATIONS', ' proc_fm_worklist_archive: Creating archive ' );
 	EXECUTE IMMEDIATE
	   'CREATE TABLE RESULTS_LOC_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM RESULTS_LOCATIONS';
	EXECUTE IMMEDIATE
	   'RENAME RESULTS_LOC_ARC TO RESULTS_LOC_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur_rl LOOP
       LogOutput('RESULTS_LOCATIONS', ' proc_fm_worklist_archive: ' || drop_cur_rec.drop_line );
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
  EXCEPTION
    WHEN OTHERS THEN
      logError('RESULTS_LOCATIONS', ' proc_fm_worklist_archive : Error during archiving-'|| SQLERRM,SQLCODE);
	  RAISE;
  END;	
END proc_fm_worklist_archive;

--
-- PROCEDURE proc_fm_aalwrk  - Execute mms aalwrk process
--
PROCEDURE proc_fm_aalwrk_post AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALWRKQ
	  WHERE	operation_code IN (1,2);
	  
 lv_wlkey          worklist.wl_key%TYPE;
BEGIN
  BEGIN
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
	  IF cur_fm_rec.product_name = ' ' THEN
	     cur_fm_rec.product_name := NULL;
	  END IF;
	  IF cur_fm_rec.shipping_comments = ' ' THEN
	     cur_fm_rec.shipping_comments := NULL;
	  END IF;
	  lv_wlkey :=get_wlkey(cur_fm_rec.po_dst_number,
			     cur_fm_rec.bo_number,
			     cur_fm_rec.style_master_sku,
			     cur_fm_rec.color_number,
			     cur_fm_rec.size_number,
			     cur_fm_rec.dimension_number,
			     cur_fm_rec.vendor_pack,
			     cur_fm_rec.quantity_per_pack,
			     cur_fm_rec.pack_sku,
                 cur_fm_rec.receiver_number);
      BEGIN
       UPDATE WORKLIST wl
	   SET wl.product_name = NVL(cur_fm_rec.product_name,wl.product_name)
	      ,wl.allocator_comments    = NVL(cur_fm_rec.shipping_comments,wl.allocator_comments)
	      ,wl.trouble_code          = NVL(cur_fm_rec.trouble_code,wl.trouble_code)
       WHERE wl.WL_KEY = lv_wlkey;
     EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	      NULL;
       WHEN OTHERS THEN
         RAISE;  
    END;
				
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALWRKQ', ' procfm_aalwrk_post : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  
  COMMIT;
END proc_fm_aalwrk_post;

--
-- PROCEDURE proc_fm_aalwrk  - Execute mms aalwrk process
--
PROCEDURE proc_fm_aalwrk_post2 AS
        
 CURSOR cur_fm IS
 	SELECT *
      FROM FM_AALWRK2Q
	  WHERE	operation_code IN (1,2);
	  
 lv_wlkey          worklist.wl_key%TYPE;
BEGIN
  BEGIN
    <<cur_fm_loop>>
    FOR cur_fm_rec IN cur_fm LOOP
	  IF cur_fm_rec.product_name = ' ' THEN
	     cur_fm_rec.product_name := NULL;
	  END IF;
	  IF cur_fm_rec.shipping_comments = ' ' THEN
	     cur_fm_rec.shipping_comments := NULL;
	  END IF;
	  lv_wlkey := cur_fm_rec.wl_key;
      BEGIN
       UPDATE WORKLIST wl
	   SET wl.product_name = NVL(cur_fm_rec.product_name,wl.product_name)
	      ,wl.allocator_comments    = NVL(cur_fm_rec.shipping_comments,wl.allocator_comments)
	      ,wl.trouble_code          = NVL(cur_fm_rec.trouble_code,wl.trouble_code)
       WHERE wl.WL_KEY = lv_wlkey;
	   
     EXCEPTION
	   WHEN NO_DATA_FOUND THEN
	      NULL;
       WHEN OTHERS THEN
         RAISE;  
    END;
				
    END LOOP cur_fm_loop;
	
  EXCEPTION
    WHEN OTHERS THEN
        
	  LogError('FM_AALWRKQ2', ' procfm_aalwrk_post2 : Error occurred transferring data-'|| SQLERRM,SQLCODE);
      ROLLBACK;  
	  RAISE;
  END;
  
  COMMIT;
END proc_fm_aalwrk_post2;

--
-- prod_db2_results2
--
-- Modifications:
-- 10/09/07 GSM Modify proc_db2_results with error handling and notification
-- 10/29/07 GSM only compare sku 8 digits- pack problems will cause 211 trouble code 
PROCEDURE proc_db2_results(p_pid VARCHAR2) AS
  lv_hsecs	    NUMBER;
  lv_maxq			NUMBER;
  lv_g_Separator	VARCHAR2(1);
	lv_First        NUMBER;
  lv_bulkerrors   NUMBER;
	lv_start_tran   VARCHAR2(4) := 'PO80';
	lv_commarea     VARCHAR2(255) := '   ';
	lv_updateuser   QUEUE_OUT.UPDATEUSER%TYPE;
	lv_updatedate   QUEUE_OUT.UPDATEDATE%TYPE;
	lv_timestamp    TIMESTAMP(2);
	lv_rollback     VARCHAR2(1) := 'N';
	lv_retry_needed BOOLEAN  := FALSE;
	lc_space        CONSTANT VARCHAR2(1) := ' ';
	lc_subject_badque CONSTANT VARCHAR2(50) := '060-1 * Arthur Allocation Release Error *  ';
	lc_body_badque    CONSTANT VARCHAR2(80) 
    := 'No allocation found for queue number.';
	lv_logmessage   VARCHAR2(500);
--2013-01-22 START
  lv_date1 VARCHAR2(10);
  LV_DATE2 VARCHAR2(10);
  NUM_ROWS INTEGER;
  SQLX VARCHAR2(1024);
--2013-01-22 FINISH

     type TRelTable is table of FM_RDQUE_VW%ROWTYPE;
     lt_RelTable$ TRelTable;
     lv_rdqrec FM_RDQUE_VW%ROWTYPE;
     lv_rdalrec RD_ARR_LINK%ROWTYPE;
     lv_qout_rec queue_out%ROWTYPE;

     procedure lp_bulkload as
     begin
     select * 
     BULK COLLECT INTO lt_RelTable$
     from 
    /*vendor pack; get details from WL only for all shape types*/
    (SELECT	LTRIM(TO_CHAR(TO_NUMBER(RTRIM(wl.PO_NBR)),'000000000000')) AS POR_ID
        ,LTRIM(TO_CHAR(TO_NUMBER(RTRIM(wl.STYLE_MASTER_SKU)),'00000000')) AS SKU_NO
        ,LTRIM(TO_CHAR(rd.location_id,'00000')) AS LOC_TOO_NO
		,LTRIM(TO_CHAR(wl.SOURCE_WHSE,'00000')) AS LOC_FRO_NO
		,rd.result_qty  AS  ALC_QY
        ,TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF2') || '0000' AS RCD_UPD_TS     
		,UPPER(SUBSTR(lv_updateuser,1,8)) AS USR_ID
	--	,wl.ALLOC_NBR AS ALC_NO  -- Use rd number to prevent queue delete error
        ,rd.allocation_nbr as ALC_NO
		,NVL(wl.SHIP_DATE,current_date) AS SHP_BY_DT
		,NVL(wl.TRANS_AD_DATE,current_date) AS TRNS_AD_DT
		,NVL(wl.ALLOCATOR_COMMENTS,lc_space) AS ALC_CMT_TX
      FROM	results_detail rd,
	    	worklist wl
     WHERE  wl.vendor_pack_id IS NOT NULL
       AND	wl.wl_key		= rd.wl_key
       -- Check to make sure we have the right product.  This is optional for vendor packs, but it doesn't hurt
       --
       -- 10/29/08 GSM only compare sku 8 digits- pack problems will caus 211 trouble code 
       --AND	(SUBSTR(rd.unique_mer_key, INSTR(rd.unique_mer_key, lv_g_Separator, -1, 1) + 1) = wl.pack_id)
       AND    (SUBSTR(rd.unique_mer_key, INSTR(rd.unique_mer_key, lv_g_Separator, -1, 1) + 1,8) 
                 = substr(wl.pack_id,1,8) )
       AND  NVL(wl.Allocator_Comments,'NotSpecialInterfaceRelease') <> 'Special Interface Release' 
       AND	rd.allocation_nbr IN (SELECT	allocation_nbr
		   					        FROM	queue_out
							       WHERE	action LIKE 'REL%'
								     AND	queue_entry_type = 'RES'
								     AND	queue_id		<= lv_maxq)


    ) UNION 				 
/* shape type 4: pack style  - not vendor pack; get details from shape table */
    (SELECT	LTRIM(TO_CHAR(TO_NUMBER(RTRIM(wl.PO_NBR)),'000000000000')) AS POR_ID
        ,LTRIM(TO_CHAR(TO_NUMBER(RTRIM(wl.STYLE_MASTER_SKU)),'00000000')) AS SKU_NO
        ,LTRIM(TO_CHAR(rd.location_id,'00000')) AS LOC_TOO_NO
		,LTRIM(TO_CHAR(wl.SOURCE_WHSE,'00000')) AS LOC_FRO_NO
		,rd.result_qty  AS  ALC_QY
        ,TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF2') || '0000' AS RCD_UPD_TS     
		,UPPER(SUBSTR(lv_updateuser,1,8)) AS USR_ID
	--	,wl.ALLOC_NBR AS ALC_NO  -- Use rd number to prevent queue delete error
        ,rd.allocation_nbr as ALC_NO
		,NVL(wl.SHIP_DATE,current_date) AS SHP_BY_DT
		,NVL(wl.TRANS_AD_DATE,current_date) AS TRNS_AD_DT
		,NVL(wl.ALLOCATOR_COMMENTS,lc_space) AS ALC_CMT_TX
      FROM	results_detail rd,
		    worklist wl,
		    pack_style st
     WHERE	wl.shape_type	= 4
       AND  wl.vendor_pack_id IS NULL
       AND	wl.wl_key		= rd.wl_key
       AND  st.wl_key = rd.wl_key
       -- Check to make sure we have the right product.
       -- 10/29/08 GSM only compare sku 8 digits- pack problems will caus 211 trouble code 
       --AND	(SUBSTR(rd.unique_mer_key, INSTR(rd.unique_mer_key, lv_g_Separator, -1, 1) + 1) = wl.pack_id)
       AND    (SUBSTR(rd.unique_mer_key, INSTR(rd.unique_mer_key, lv_g_Separator, -1, 1) + 1,8) 
                 = substr(st.pack_id,1,8) )
       AND  NVL(wl.Allocator_Comments,'NotSpecialInterfaceRelease') <> 'Special Interface Release' 
       AND	rd.allocation_nbr IN (SELECT	allocation_nbr
							        FROM	queue_out
							       WHERE	action LIKE 'REL%'
								     AND	queue_entry_type = 'RES'
								     AND	queue_id		<= lv_maxq)
    )
    order by 8,1,2;
    end;
 
BEGIN

   lv_hsecs := dbms_utility.get_time;
   
   DBMS_OUTPUT.ENABLE  (1120000);
   
   gv_logfile := utl_file.fopen('ALC_LOG'
	                             ,'allocmagic_results'
								 || p_pid
								 || '.log'
								 , 'W');
								 
-- Get a released queue id to process
	SELECT	MAX(queue_id)
	  INTO	lv_maxq
	  FROM	queue_out
	 WHERE	action LIKE 'REL%'
	   AND	queue_entry_type = 'RES';
       
	IF  lv_maxq IS NULL THEN
	  DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		                        ' No data to process ');
      utl_file.fclose_all;
	  RETURN;
    END IF;

    logOutput('QUEUE_OUT',
				 ' proc_db2_results: select queue id:' 
				 || lv_maxq);
    utl_file.fflush(gv_logfile);
	
-- Get user who released
   	SELECT	updateuser
	  INTO	lv_updateuser
	  FROM	queue_out
	 WHERE	queue_id = lv_maxq
	   AND	ROWNUM < 2;
	
	SELECT	value
	  INTO	lv_g_Separator
	  FROM	params
	 WHERE	TYPE = 'WORKLIST'
	   AND	code = 'WL_UNIQ_KEY_SEPARATOR';

    lp_bulkload;
    
    lv_timestamp := SYSTIMESTAMP + numtodsinterval(3,'HOUR');  
    
    BEGIN 
        lv_rdqrec := lt_RelTable$(lt_RelTable$.First);
        lv_First  := lt_RelTable$.First;
    EXCEPTION
      WHEN OTHERS THEN
        lv_logmessage := ' proc_db2_results:' || ' No data found for Queue ID ' 
                         || lv_maxq;
        logError('RESULTS_DETAIL',lv_logmessage);
        utl_file.fflush(gv_logfile);
        DELETE FROM queue_out 
           WHERE queue_id=lv_maxq
           RETURNING queue_id
                    ,allocation_nbr
                    ,updateuser
                    ,updatedate 
               INTO lv_qout_rec.queue_id
                   ,lv_qout_rec.allocation_nbr
                   ,lv_updateuser
                   ,lv_updatedate;
        lv_logmessage := ' proc_db2_results: not processed: ' 
             || lv_qout_rec.queue_id || ' - ' || lv_qout_rec.allocation_nbr
             || ' - euid: ' || substr(lv_updateuser,1,8)
             || ' date: ' || to_char(lv_updatedate,'YYYY-MM-DD-HH24.MI.SS')
             ;
        logOutput('QUEUE_OUT',lv_logmessage);
        UTL_FILE.FFLUSH(GV_LOGFILE);
        notify_oncall(lc_subject_badque,lc_body_badque ||  gv_LF || lv_logmessage);
        utl_file.fclose(gv_logfile);
        DBMS_LOCK.sleep(1);
        RETURN;
    END;
    
    FOR ix1 in lt_RelTable$.First..(lt_RelTable$.Last + 1)
     LOOP
      IF ix1 > lt_RelTable$.Last 
       OR lv_rdqrec.SKU_NO <> lt_RelTable$(ix1).SKU_NO THEN 
           COMMIT;
           FOR ix2 in lv_First..(ix1 - 1)
             LOOP
               lv_rdqrec := lt_RelTable$(ix2);
               INSERT INTO RD_ARR_LINK 
               VALUES (lv_rdqrec.POR_ID
               ,lv_rdqrec.SKU_NO       
               ,lv_rdqrec.LOC_TOO_NO
               ,lv_rdqrec.LOC_FRO_NO
               ,lv_rdqrec.ALC_QY    
               ,lv_rdqrec.RCD_UPD_TS
               ,lv_rdqrec.USR_ID    
               ,lv_rdqrec.ALC_NO    
               ,lv_rdqrec.SHP_BY_DT             
               ,lv_rdqrec.TRNS_AD_DT
               ,lv_rdqrec.ALC_CMT_TX
               ,CASE lv_rollback WHEN 'Y' THEN 'E' ELSE 'C' END
               );
             END loop;
           COMMIT;
          IF lv_rollback = 'Y' THEN
             lv_retry_needed := TRUE;
          END IF;
          lv_First := ix1;
          lv_rollback := 'N';
      END IF;
      EXIT WHEN ix1 > lt_RelTable$.Last;
      IF lv_rollback = 'N' THEN
          lv_rdqrec := lt_RelTable$(ix1);
--2017-03-03 START - strip quote marks
          lv_rdqrec.ALC_CMT_TX := replace(lv_rdqrec.ALC_CMT_TX,'''','');
--2017-03-03 END
    	  lv_rdqrec.RCD_UPD_TS :=
    	    TO_CHAR(lv_timestamp + 
            numtodsinterval(ix1 * .01,'SECOND'),
            'YYYY-MM-DD-HH24.MI.SS.FF2') || '0000';
--2013-01-22 START
        --lv_rdqrec.SHP_BY_DT := TO_CHAR(lv_rdqrec.SHP_BY_DT, 'YYYY-MM-DD');
        --lv_rdqrec.TRNS_AD_DT := TO_CHAR(lv_rdqrec.TRNS_AD_DT, 'YYYY-MM-DD');
--2013-01-22 FINISH
          BEGIN
--2013-01-22 START
            --insert into ARR_ALOC_RSULT_RCD values lv_rdqrec;
            lv_date1 := TO_CHAR(lv_rdqrec.SHP_BY_DT, 'YYYY-MM-DD');
            LV_DATE2 := TO_CHAR(LV_RDQREC.TRNS_AD_DT, 'YYYY-MM-DD');
--2016-09-12 ORACLE BUG WORKAROUND START
--            insert into ARR_ALOC_RSULT_RCD values
--               (lv_rdqrec.POR_ID
--               ,lv_rdqrec.SKU_NO       
--               ,lv_rdqrec.LOC_TOO_NO
--               ,lv_rdqrec.LOC_FRO_NO
--               ,lv_rdqrec.ALC_QY    
--               ,lv_rdqrec.RCD_UPD_TS
--               ,lv_rdqrec.USR_ID    
--               ,lv_rdqrec.ALC_NO    
--               ,lv_date1            
--               ,lv_date2
--               ,LV_RDQREC.ALC_CMT_TX);
            sqlx := '
            insert into ' || allocmagicconst.db2env || '.ARR_ALOC_RSULT_RCD values
               (''' || lv_rdqrec.POR_ID || ''',
                ''' || LV_RDQREC.SKU_NO || ''',  
                ''' || LV_RDQREC.LOC_TOO_NO || ''',
                ''' || LV_RDQREC.LOC_FRO_NO || ''',
                '  || LV_RDQREC.ALC_QY || ',
                ''' || LV_RDQREC.RCD_UPD_TS || ''',
                ''' || LV_RDQREC.USR_ID || ''',
                '  || LV_RDQREC.ALC_NO || ',
                ''' || LV_DATE1 || ''',            
                ''' || LV_DATE2 || ''',
                ''' || LV_RDQREC.ALC_CMT_TX || ''')';
                NUM_ROWS :=  DBMS_HS_PASSTHROUGH.EXECUTE_IMMEDIATE@DB2MAGIC(sqlx);
--2016-09-12 ORACLE BUG WORKAROUND END
--2013-01-22 FINISH
          EXCEPTION
    	    WHEN OTHERS THEN
              ROLLBACK;
              lv_rollback := 'Y';
              logError('ARR_ALOC_RSULT_RCD@DB2MAGIC', 
                ' proc_db2_results : insert error : ' || 
                lv_rdqrec.SKU_NO || '-' ||
                lv_rdqrec.ALC_NO || '-' ||
                lv_rdqrec.POR_ID || ' >> ' ||
                 SQLERRM,SQLCODE); 
              logError('SQLX', sqlx);
          END;
      END IF;
     END LOOP;
    
    COMMIT;   
	
    logOutput('ARR_ALOC_RSULT_RCD@DB2MAGIC',
				 ' proc_db2_results: process count:' 
				 || lt_RelTable$.Last);

/* Remove processed items from Queue_out */
    FOR ix3 IN lt_RelTable$.First..lt_RelTable$.Last 
    LOOP
      lv_rdqrec := lt_RelTable$(ix3);
      IF lv_qout_rec.allocation_nbr IS NULL 
        OR lv_qout_rec.allocation_nbr <> lv_rdqrec.ALC_NO THEN
          DELETE FROM queue_out 
           WHERE allocation_nbr=lv_rdqrec.ALC_NO
           RETURNING queue_id,allocation_nbr 
               INTO lv_qout_rec.queue_id,lv_qout_rec.allocation_nbr;
          logOutput('QUEUE_OUT',
             ' proc_db2_results: processed: ' 
             || lv_qout_rec.queue_id || ' - ' || lv_qout_rec.allocation_nbr);
      END IF;
    END LOOP;
  
    utl_file.fflush(gv_logfile);
   
    COMMIT;
    
	IF lv_retry_needed THEN
       gv_sent := SendRequest('Allocmagic.proc_db2_results_retry');
    END IF;

-- Start the Magic transaction to process data	   
	lv_commarea := ':' || TO_CHAR(lv_maxq) || ':' || lv_updateuser;
    Allocmagic.proc_fm_cics(Allocmagicconst.gc_cics_server,
	                        Allocmagicconst.gc_cics_port,lv_start_tran,lv_commarea);
	
	
    --utl_file.fclose_all;

    LogOutput(NULL,' Completed Results processing');
	LogOutput(NULL,' -------------------- Elapsed: ' ||
		             TimeConvert(dbms_utility.get_time - lv_hsecs) ||
					 ' ------------------');-- Open results log file

    utl_file.fclose(gv_logfile);

    DBMS_LOCK.sleep(1);
						
EXCEPTION
  WHEN OTHERS THEN
    logError('ARR_ALOC_RSULT_RCD@DB2MAGIC', 
            ' proc_db2_results : Other error : ' || SQLERRM,SQLCODE);
    utl_file.fclose(gv_logfile);
    ROLLBACK;
    RAISE;   
END proc_db2_results;

--
-- prod_db2_results2_retry
--
PROCEDURE proc_db2_results_retry AS
  lv_maxq			NUMBER;
  lv_g_Separator	VARCHAR2(1);
	lv_First        NUMBER;
	lv_start_tran   VARCHAR2(4) := 'PO80';
	lv_commarea     VARCHAR2(255) := '   ';
	lv_updateuser   QUEUE_OUT.UPDATEUSER%TYPE;
	lv_timestamp    TIMESTAMP(2);
	lv_rollback     VARCHAR2(1) := 'N';
	lc_space        CONSTANT VARCHAR2(1) := ' ';
	lc_subject      CONSTANT VARCHAR2(50) := '060-1 * Arthur Allocation Release Error *  ';
	lc_body         CONSTANT VARCHAR2(80) 
    := 'An error occured while trying to insert record onto the ARR table.   ';
	LV_LOGMESSAGE   VARCHAR2(500);
  NUM_ROWS INTEGER;
  SQLX VARCHAR2(1024);

     type TRelTable is table of FM_RDQUE_VW%ROWTYPE;
     lt_RelTable$ TRelTable;
     lv_rdqrec FM_RDQUE_VW%ROWTYPE;
     lv_rdalrec RD_ARR_LINK%ROWTYPE;
--2013-01-22 START
  lv_date1 VARCHAR2(10);
  lv_date2 VARCHAR2(10);
--2013-01-22 FINISH

     procedure lp_bulkload as
     begin
     select POR_ID
        ,SKU_NO
        ,LOC_TOO_NO
		,LOC_FRO_NO
		,ALC_QY
        ,RCD_UPD_TS     
		,USR_ID
		,ALC_NO
		,SHP_BY_DT
		,TRNS_AD_DT
		,ALC_CMT_TX 
     BULK COLLECT INTO lt_RelTable$
      FROM	rd_arr_link 
     WHERE  arr_status in ('E')
     ORDER BY 6,8,1,2;
    end;
 
BEGIN
    lp_bulkload;
    
    lv_timestamp := SYSTIMESTAMP + numtodsinterval(3,'HOUR');  
    
    IF lt_RelTable$.First IS NULL THEN
      DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6')
               || ' proc_db2_results_retry : * No results found with errors * ');

      RETURN;
    END IF;
    lv_rdqrec := lt_RelTable$(lt_RelTable$.First);
    lv_First  := lt_RelTable$.First;
    
    FOR ix1 in lt_RelTable$.First..(lt_RelTable$.Last + 1)
     LOOP
      IF ix1 > lt_RelTable$.Last 
       OR lv_rdqrec.SKU_NO <> lt_RelTable$(ix1).SKU_NO THEN 
           COMMIT;
           UPDATE RD_ARR_LINK 
            SET arr_status = CASE lv_rollback WHEN 'Y' THEN 'N' ELSE 'C' END
           WHERE SKU_NO = lv_rdqrec.SKU_NO
             AND ALC_NO = lv_rdqrec.ALC_NO
             AND POR_ID = lv_rdqrec.POR_ID;
          COMMIT;
          IF LV_ROLLBACK = 'Y' THEN
              notify_oncall(lc_subject,lc_body ||  gv_LF || lv_logmessage);
          END IF;
          lv_First := ix1;
          lv_rollback := 'N';
      END IF;
      EXIT WHEN ix1 > lt_RelTable$.Last;
      IF lv_rollback = 'N' THEN
          lv_rdqrec := lt_RelTable$(ix1);
--2017-03-03 START - strip quote marks
          lv_rdqrec.ALC_CMT_TX := replace(lv_rdqrec.ALC_CMT_TX,'''','');
--2017-03-03 END    	  lv_rdqrec.RCD_UPD_TS :=
    	  lv_rdqrec.RCD_UPD_TS :=
    	    TO_CHAR(lv_timestamp + 
            numtodsinterval(ix1 * .01,'SECOND'),
            'YYYY-MM-DD-HH24.MI.SS.FF2') || '0000';
          BEGIN
--            insert into ARR_ALOC_RSULT_RCD values lv_rdqrec;
--2013-01-22 START
            --insert into ARR_ALOC_RSULT_RCD values lv_rdqrec;
            lv_date1 := TO_CHAR(lv_rdqrec.SHP_BY_DT, 'YYYY-MM-DD');
            LV_DATE2 := TO_CHAR(LV_RDQREC.TRNS_AD_DT, 'YYYY-MM-DD');
--2016-09-12 ORACLE BUG WORKAROUND START
--            insert into ARR_ALOC_RSULT_RCD values
--               (lv_rdqrec.POR_ID
--               ,lv_rdqrec.SKU_NO       
--               ,lv_rdqrec.LOC_TOO_NO
--               ,lv_rdqrec.LOC_FRO_NO
--               ,lv_rdqrec.ALC_QY    
--               ,lv_rdqrec.RCD_UPD_TS
--               ,lv_rdqrec.USR_ID    
--               ,lv_rdqrec.ALC_NO    
--               ,lv_date1            
--               ,LV_DATE2
--               ,lv_rdqrec.ALC_CMT_TX);
            sqlx := '
            insert into ' || allocmagicconst.db2env || '.ARR_ALOC_RSULT_RCD values
               (''' || lv_rdqrec.POR_ID || ''',
                ''' || LV_RDQREC.SKU_NO || ''',  
                ''' || LV_RDQREC.LOC_TOO_NO || ''',
                ''' || LV_RDQREC.LOC_FRO_NO || ''',
                '  || LV_RDQREC.ALC_QY || ',
                ''' || LV_RDQREC.RCD_UPD_TS || ''',
                ''' || LV_RDQREC.USR_ID || ''',
                '  || LV_RDQREC.ALC_NO || ',
                ''' || LV_DATE1 || ''',            
                ''' || LV_DATE2 || ''',
                ''' || LV_RDQREC.ALC_CMT_TX || ''')';
                NUM_ROWS :=  DBMS_HS_PASSTHROUGH.EXECUTE_IMMEDIATE@DB2MAGIC(SQLX);
--2016-09-12 ORACLE BUG WORKAROUND END

--2013-01-22 FINISH
          EXCEPTION
    	    WHEN OTHERS THEN
              ROLLBACK;
              lv_rollback := 'Y';
              lv_logmessage := ' proc_db2_results_retry : insert error : ' || 
                 lv_rdqrec.SKU_NO || '-' ||
                 lv_rdqrec.ALC_NO || '-' ||
                 lv_rdqrec.POR_ID || gv_LF || ' >> ' ||
                 SQLCODE || '-' || SQLERRM;
              logError('ARR_ALOC_RSULT_RCD@DB2MAGIC',lv_logmessage);    	 
          END;
      END IF;
     END LOOP;
    
    COMMIT;   
	
    logOutput('ARR_ALOC_RSULT_RCD@DB2MAGIC',
				 ' proc_db2_results_retry: process count:' 
				 || lt_RelTable$.Last);

    utl_file.fflush(gv_logfile);
   
-- Start the Magic transaction to process data	   
	lv_commarea := ':' || TO_CHAR(lv_maxq) || ':' || lv_updateuser;
    Allocmagic.proc_fm_cics(Allocmagicconst.gc_cics_server,
	                        Allocmagicconst.gc_cics_port,lv_start_tran,lv_commarea);
	
--    utl_file.fclose_all;
	
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD-HH24.MI.SS.FF6') || 
		                 ' proc_db2_results_retry: Completed Results processing');
						 
    DBMS_LOCK.sleep(1);
						
EXCEPTION
  WHEN OTHERS THEN
    logError('ARR_ALOC_RSULT_RCD@DB2MAGIC', 
            ' proc_db2_results_retry: Other error: ' || SQLERRM,SQLCODE);
    ROLLBACK;
    RAISE;   
END PROC_DB2_RESULTS_RETRY;

--
-- Create db2 results ARR interface table archive
--
PROCEDURE proc_db2_results_archive AS

lv_days_limit  NUMBER := 45;

CURSOR drop_cur IS
   SELECT 'drop table ' || table_name AS drop_line
     FROM all_tables
    WHERE  table_name BETWEEN UPPER('RD_ARR_LINK_arc000000000000') 
      AND UPPER('RD_ARR_LINK_arc')|| TO_CHAR(SYSDATE - lv_days_limit,'YYMMDD') ||'000000';
	  
BEGIN
    <<drop_old_archive>>
    FOR drop_cur_rec IN drop_cur LOOP
	   EXECUTE IMMEDIATE drop_cur_rec.drop_line;
	END LOOP drop_old_archive;
	
 	EXECUTE IMMEDIATE
	   'CREATE TABLE RD_ARR_LINK_ARC' || gv_LF || 
	   ' NOLOGGING AS ' ||
	   ' SELECT * FROM RD_ARR_LINK WHERE 1=0';
	EXECUTE IMMEDIATE
	   'ALTER TABLE RD_ARR_LINK ' || gv_LF || 
	   ' EXCHANGE PARTITION RD_ARR_LINK_01' || gv_LF ||
	   ' WITH TABLE RD_ARR_LINK_ARC ';
	EXECUTE IMMEDIATE
	   'RENAME RD_ARR_LINK_ARC TO RD_ARR_LINK_ARC' 
	    || TO_CHAR(SYSTIMESTAMP,'YYMMDDHH24MISS');
		
EXCEPTION
  WHEN OTHERS THEN
    logError('RD_ARR_LINK', ' proc_db2_results_archive : Error during results archiving-'|| SQLERRM,SQLCODE);
	
END proc_db2_results_archive;

--
-- PROCEDURE proc_fm_cics  - Start CICS tran
--
PROCEDURE proc_fm_cics(p_cics_server IN VARCHAR2
                      ,p_cics_port IN NUMBER
                      ,p_start_tran IN VARCHAR2
                      ,p_commarea  IN VARCHAR2) AS
BEGIN
  DECLARE
    c  utl_tcp.connection;  -- TCP/IP connection to echo port
    ret_val PLS_INTEGER; 
  BEGIN
    c := utl_tcp.open_connection(remote_host => p_cics_server,
                               remote_port =>  p_cics_port,
                               charset     => NULL);  -- open connection
    ret_val := utl_tcp.write_line(c,p_start_tran || p_commarea); -- send string to server

	utl_tcp.close_all_connections;

  END;
END proc_fm_cics;

/************************************************************************
 * GSM Added 07/128/06...				*
 ************************************************************************/
/* This procedure updateS product hirachy changes daily on aam Stage tables
*/
PROCEDURE proc_fm_aalsty_stage2
   AS
		CURSOR cs_item_name
         IS
--            SELECT /*+parallel(ite,5) */ DISTINCT ite.sku_number
            SELECT /*+parallel(ite,5) */ DISTINCT pre.style_master_sku
			              , pre.dept_nbr
			              , pre.subdept_nbr
						        , pre.class_nbr
                    , pre.item_group_nbr
						        , pre.subclass_nbr
                    , pre.choice_nbr
			              , ite.department_number
			              , ite.subdepartment_number
						        , ite.class_number
                    , ite.item_group_number
						        , ite.subclass_number
                    , ite.choice_number
                       FROM AALSTY ite, STAGE_DIMENSION pre
--                      WHERE (ite.sku_number = pre.style_master_sku)
                      WHERE (ite.sku_number = pre.sku_nbr)
					              AND ite.operation_code IN ('1','2')
						            AND ((ite.department_number <> pre.dept_nbr)
                         OR (ite.subdepartment_number <> pre.subdept_nbr)
                         OR (ite.class_number <> pre.class_nbr)
                         OR (ite.item_group_number <> pre.item_group_nbr)
                         OR (ite.subclass_number <> pre.subclass_nbr)
                         OR (ite.choice_number <> pre.choice_nbr))
                   order by pre.choice_nbr, ite.choice_number;
					  
         CHUNK  CONSTANT       PLS_INTEGER		:= 10;
         record_no		       PLS_INTEGER		:= 0;
         truncstring           VARCHAR2 (2000);
         cv_style_master_sku   LIST_SKU.style_master_sku%TYPE;
         cv_old_dept_nbr       LIST_SKU.dept_nbr%TYPE;
         cv_old_subdept_nbr    LIST_SKU.subdept_nbr%TYPE;
         cv_old_class_nbr      LIST_SKU.class_nbr%TYPE;
         cv_old_itg_nbr        LIST_SKU.item_group_nbr%TYPE;
         cv_old_subclass_nbr   LIST_SKU.subclass_nbr%TYPE;
         cv_old_chs_nbr        LIST_SKU.choice_nbr%TYPE;
         cv_dept_nbr           LIST_SKU.dept_nbr%TYPE;
         cv_subdept_nbr        LIST_SKU.subdept_nbr%TYPE;
         cv_class_nbr          LIST_SKU.class_nbr%TYPE;
         cv_itg_nbr            LIST_SKU.item_group_nbr%TYPE;
         cv_subclass_nbr       LIST_SKU.subclass_nbr%TYPE;
         cv_chs_nbr            LIST_SKU.choice_nbr%TYPE;
         last_style_master_sku LIST_SKU.style_master_sku%TYPE;
         last_old_dept_nbr     LIST_SKU.dept_nbr%TYPE;
         last_old_subdept_nbr  LIST_SKU.subdept_nbr%TYPE;
         last_old_class_nbr    LIST_SKU.class_nbr%TYPE;
         last_old_itg_nbr      LIST_SKU.item_group_nbr%TYPE;
         last_old_subclass_nbr LIST_SKU.subclass_nbr%TYPE := 0;
         last_new_dept_nbr     LIST_SKU.dept_nbr%TYPE;
         last_new_subdept_nbr  LIST_SKU.subdept_nbr%TYPE;
         last_new_class_nbr    LIST_SKU.class_nbr%TYPE;
         last_new_itg_nbr      LIST_SKU.item_group_nbr%TYPE;
         last_new_subclass_nbr LIST_SKU.subclass_nbr%TYPE := 0;
 	     lv_bTableTruncated    BOOLEAN;
         lv_count	           PLS_INTEGER		:= 0;
         lv_del_count	       PLS_INTEGER		:= 0;

	  BEGIN
		LogOutput (null,'proc_fm_aalsty_stage: Waiting for sty process ');
		--Wait for sty process
        LOCK TABLE aalsty IN EXCLUSIVE MODE; 
		LogOutput (null,'proc_fm_aalsty_stage: Begin Process ');

		OPEN cs_item_name;

        LOOP
          FETCH cs_item_name
             INTO cv_style_master_sku,
			     cv_old_dept_nbr, cv_old_subdept_nbr, cv_old_class_nbr,
                  cv_old_itg_nbr, cv_old_subclass_nbr, cv_old_chs_nbr,
			     cv_dept_nbr, cv_subdept_nbr, cv_class_nbr,
                  cv_itg_nbr, cv_subclass_nbr, cv_chs_nbr;

          EXIT WHEN cs_item_name%NOTFOUND;
          BEGIN
             UPDATE STAGE_DIMENSION pre
                  SET pre.dept_nbr = cv_dept_nbr,
                      pre.subdept_nbr = cv_subdept_nbr,
                      pre.class_nbr = cv_class_nbr,
                      pre.item_group_nbr = cv_itg_nbr,
                      pre.subclass_nbr = cv_subclass_nbr,
                      pre.choice_nbr = cv_chs_nbr
                WHERE pre.style_master_sku = cv_style_master_sku;
				
			   lv_count := sql%ROWCOUNT;
		    -- Line counter for records counting.
		    record_no := record_no + 1;
			
		 EXCEPTION
           WHEN DUP_VAL_ON_INDEX THEN
             INSERT INTO LIST_SKU_AUDIT
                              (style_master_sku, dept_nbr, subdept_nbr,
                               class_nbr, item_group_nbr, subclass_nbr, choice_nbr
                              )
                       VALUES (cv_style_master_sku, cv_dept_nbr, cv_subdept_nbr,
                               cv_class_nbr, cv_itg_nbr, cv_subclass_nbr, cv_chs_nbr
                              );
         END;                                 /* Update...Exception loop */

         last_style_master_sku := cv_style_master_sku;
         last_old_dept_nbr     := cv_old_dept_nbr;
         last_old_subdept_nbr  := cv_old_subdept_nbr;
         last_old_class_nbr    := cv_old_class_nbr ;
         last_old_itg_nbr      := cv_old_itg_nbr;
         last_old_subclass_nbr := cv_old_subclass_nbr;
         last_new_dept_nbr     := cv_dept_nbr;
         last_new_subdept_nbr  := cv_subdept_nbr;
         last_new_class_nbr    := cv_class_nbr;
         last_new_itg_nbr      := cv_itg_nbr;
         last_new_subclass_nbr := cv_subclass_nbr;
			   
		 IF MOD (record_no, CHUNK) = 0 THEN -- for testing
			  -- Inserts into log_table every "chunk" number of records.
	          COMMIT;
		      LogOutput (NULL,'proc_fm_aalsty_stage: Records Committed ',NULL, record_no,
		                 NULL, NULL, NULL, NULL, NULL, cv_style_master_sku);
						 
		 END IF;
     END LOOP;
	   
	   
	   IF record_no > 0 THEN
	      cv_subclass_nbr     := 0;
	      cv_old_subclass_nbr := 0;
	   END IF;
	   
       CLOSE cs_item_name;
       COMMIT;
	   LogOutput (NULL,'proc_fm_aalsty_stage: Last Record Committed ',NULL, record_no,
		                 NULL, NULL, NULL, NULL, NULL, cv_style_master_sku);

EXCEPTION
	WHEN OTHERS THEN
		LogError (NULL, 'proc_fm_aalsty_stage: Error during process: ' || SQLERRM, SQLCODE, record_no);
		ROLLBACK;
		RAISE;    -- Send the error back so that we'll get a log in the middleware.
END proc_fm_aalsty_stage2 ;

-- FM create procedure to sync worklist with list_sku hierarchy changes
PROCEDURE proc_fm_prdsync_worklist
AS
 lv_count NUMBER := 0;
BEGIN
  LogOutput('WORKLIST', ' proc_fm_prdsync_worklist: Start  ');
  

  UPDATE WORKLIST WLU
     SET (dept_nbr,dept_name)         = (SELECT  ls.dept_nbr,rtrim(dept_name)
	                                       FROM list_sku ls,aam.list_dept ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku
							                AND LS.DEPT_NBR=LN.DEPT_NBR(+)),
         (subdept_nbr,subdept_name)   = (SELECT  ls.subdept_nbr,rtrim(subdept_name) 
		                                   FROM list_sku ls,aam.list_subdept ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku
							                AND ls.dept_nbr=ln.dept_nbr(+) 
										    AND LS.SUBDEPT_NBR=LN.SUBDEPT_NBR(+)),
         (class_nbr,class_name)       = (SELECT  ls.class_nbr,rtrim(class_name)
		                                   FROM list_sku ls,aam.list_class ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku 
							                AND ls.dept_nbr=ln.dept_nbr(+) 
										    AND ls.subdept_nbr=ln.subdept_nbr(+) 
										    AND LS.CLASS_NBR=LN.CLASS_NBR(+)),	
         (item_group_nbr,item_group_name)       = (SELECT  ls.item_group_nbr,rtrim(item_group_name)
		                                   FROM list_sku ls,aam.list_item_group ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku 
							                AND ls.dept_nbr=ln.dept_nbr(+) 
										    AND ls.subdept_nbr=ln.subdept_nbr(+) 
										    AND ls.class_nbr=ln.class_nbr(+)
                        AND LS.ITEM_GROUP_NBR=LN.ITEM_GROUP_NBR(+)),		
         (subclass_nbr,subclass_name) = (SELECT  ls.subclass_nbr,rtrim(subclass_name) 
		                                   FROM list_sku ls,aam.list_subclass ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku
							                AND ls.dept_nbr=ln.dept_nbr(+) 
											AND ls.subdept_nbr=ln.subdept_nbr(+) 
											AND ls.class_nbr=ln.class_nbr(+) 
                      AND ls.item_group_nbr=ln.item_group_nbr(+)
											AND LS.SUBCLASS_NBR=LN.SUBCLASS_NBR(+)),
         (choice_nbr,choice_name) = (SELECT  ls.choice_nbr,rtrim(choice_name)
		                                   FROM list_sku ls,aam.list_choice ln 
                                          WHERE ls.style_master_sku=wlu.style_master_sku
							                AND ls.dept_nbr=ln.dept_nbr(+) 
											AND ls.subdept_nbr=ln.subdept_nbr(+) 
											AND ls.class_nbr=ln.class_nbr(+) 
                      AND ls.item_group_nbr=ln.item_group_nbr(+)
											AND ls.subclass_nbr=ln.subclass_nbr(+)
                      AND LS.CHOICE_NBR=LN.CHOICE_NBR(+)),
         (product_name)      = (SELECT  rtrim(ls.product_name)
		                                   FROM list_sku ls 
                                          WHERE ls.style_master_sku=wlu.style_master_sku)											
  WHERE wl_key IN 
   (	select /*+parallel(wl,5) */ wl_key
          from worklist wl,list_sku ls
         where status_code in (10,30) and wl.style_master_sku=ls.style_master_sku
           and (nvl(wl.dept_nbr,0) != ls.dept_nbr
                or nvl(wl.subdept_nbr,0) != ls.subdept_nbr
	            or nvl(wl.class_nbr,0) != ls.class_nbr
              or wl.item_group_nbr != ls.item_group_nbr
	            or nvl(wl.subclass_nbr,0) != ls.subclass_nbr	
              or nvl(wl.choice_nbr,0) != ls.choice_nbr	
	            or nvl(wl.product_name,0) != ls.product_name				
                or wl.dept_name is null
                or wl.subdept_name is null
                or wl.class_name is null
                or wl.item_group_name is null
                or wl.subclass_name is null  
                or wl.choice_name is null
                or wl.product_name is null
                ));  

 lv_count := sql%ROWCOUNT;
 			
 COMMIT;

 LogOutput('WORKLIST', ' proc_fm_prdsync_worklist: Rows processed for structure: ' || lv_count);
 
 UPDATE WORKLIST WLU
     SET (ATTR_1_CODE
         ,ATTR_1_DESC         
         ,ATTR_2_CODE
         ,ATTR_2_DESC
         ,ATTR_3_CODE
         ,ATTR_3_DESC
         ,ATTR_4_CODE
         ,ATTR_4_DESC
         ,ATTR_5_CODE
         ,ATTR_5_DESC
         ,ATTR_6_CODE
         ,ATTR_6_DESC
         ,ATTR_7_CODE
         ,ATTR_7_DESC
         ,ATTR_8_CODE
         ,ATTR_8_DESC
         ,ATTR_9_CODE
         ,ATTR_9_DESC
         ,ATTR_10_CODE
         ,ATTR_10_DESC
         ,ATTR_11_CODE
         ,ATTR_11_DESC
         ,ATTR_12_CODE
         ,ATTR_12_DESC)
     = (SELECT  rtrim(a1.ATTR_1_CODE)      ATTR_1_CODE  
               ,rtrim(a1.ATTR_1_DESC)      ATTR_1_DESC
               ,rtrim(a2.ATTR_2_CODE)      ATTR_2_CODE
               ,rtrim(a2.ATTR_2_DESC)      ATTR_2_DESC
               ,rtrim(a3.ATTR_3_CODE)      ATTR_3_CODE
               ,rtrim(a3.ATTR_3_DESC)      ATTR_3_DESC
               ,rtrim(a4.ATTR_4_CODE)      ATTR_4_CODE
               ,rtrim(a4.ATTR_4_DESC)      ATTR_4_DESC
               ,rtrim(a5.ATTR_5_CODE)      ATTR_5_CODE
               ,rtrim(a5.ATTR_5_DESC)      ATTR_5_DESC
               ,rtrim(a6.ATTR_6_CODE)      ATTR_6_CODE
               ,rtrim(a6.ATTR_6_DESC)      ATTR_6_DESC
               ,rtrim(a7.ATTR_7_CODE)      ATTR_7_CODE
               ,rtrim(a7.ATTR_7_DESC)      ATTR_7_DESC
               ,rtrim(a8.ATTR_8_CODE)      ATTR_8_CODE
               ,rtrim(a8.ATTR_8_DESC)      ATTR_8_DESC
               ,rtrim(a9.ATTR_9_CODE)      ATTR_9_CODE
               ,rtrim(a9.ATTR_9_DESC)      ATTR_9_DESC
               ,rtrim(a10.ATTR_10_CODE)    ATTR_10_CODE
               ,rtrim(a10.ATTR_10_DESC)    ATTR_10_DESC
               ,rtrim(a11.ATTR_11_CODE)    ATTR_11_CODE
               ,rtrim(a11.ATTR_11_DESC)    ATTR_11_DESC
               ,rtrim(a12.ATTR_12_CODE)    ATTR_12_CODE
               ,rtrim(a12.ATTR_12_DESC)    ATTR_12_DESC
      FROM fm_aalatrs_archive atrs
         left outer join aam.LIST_ATTR_1 a1 on rtrim(a1.ATTR_1_CODE)=rtrim(atrs.ATTR_1_CODE)
         left outer join aam.LIST_ATTR_2 a2 on rtrim(a2.ATTR_2_CODE)=rtrim(atrs.ATTR_2_CODE)
         left outer join aam.LIST_ATTR_3 a3 on rtrim(a3.ATTR_3_CODE)=rtrim(atrs.ATTR_3_CODE)
         left outer join aam.LIST_ATTR_4 a4 on rtrim(a4.ATTR_4_CODE)=rtrim(atrs.ATTR_4_CODE)
         left outer join aam.LIST_ATTR_5 a5 on rtrim(a5.ATTR_5_CODE)=rtrim(atrs.ATTR_5_CODE)
         left outer join aam.LIST_ATTR_6 a6 on rtrim(a6.ATTR_6_CODE)=rtrim(atrs.ATTR_6_CODE)
         left outer join aam.LIST_ATTR_7 a7 on rtrim(a7.ATTR_7_CODE)=rtrim(atrs.ATTR_7_CODE)
         left outer join aam.LIST_ATTR_8 a8 on rtrim(a8.ATTR_8_CODE)=rtrim(atrs.ATTR_8_CODE)
         left outer join aam.LIST_ATTR_9 a9 on rtrim(a9.ATTR_9_CODE)=rtrim(atrs.ATTR_9_CODE)
         left outer join aam.LIST_ATTR_10 a10 on rtrim(a10.ATTR_10_CODE)=rtrim(atrs.ATTR_10_CODE)       
         left outer join aam.LIST_ATTR_11 a11 on rtrim(a11.ATTR_11_CODE)=rtrim(atrs.ATTR_11_CODE)       
         left outer join aam.LIST_ATTR_12 a12 on rtrim(a12.ATTR_12_CODE)=rtrim(atrs.ATTR_12_CODE)  
    WHERE  atrs.sku_nbr   = WLU.style_master_sku 
    )
  WHERE 
  wl_key IN 
   (    select /*+parallel(wl) */ wl_key
          from worklist wl,aamfm.fm_aalatrs_archive atrs
         where status_code in (10,30) and wl.style_master_sku=atrs.sku_nbr
           and (nvl(wl.ATTR_1_CODE,0) != atrs.ATTR_1_CODE
                or wl.ATTR_1_DESC is null
                or nvl(wl.ATTR_2_CODE,0) != atrs.ATTR_2_CODE
                or wl.ATTR_2_DESC is null           
                or nvl(wl.ATTR_3_CODE,0) != atrs.ATTR_3_CODE
                or wl.ATTR_3_DESC is null           
                or nvl(wl.ATTR_4_CODE,0) != atrs.ATTR_4_CODE
                or wl.ATTR_4_DESC is null           
                or nvl(wl.ATTR_5_CODE,0) != atrs.ATTR_5_CODE
                or wl.ATTR_5_DESC is null           
                or nvl(wl.ATTR_6_CODE,0) != atrs.ATTR_6_CODE
                or wl.ATTR_6_DESC is null           
                or nvl(wl.ATTR_7_CODE,0) != atrs.ATTR_7_CODE
                or wl.ATTR_7_DESC is null           
                or nvl(wl.ATTR_8_CODE,0) != atrs.ATTR_8_CODE
                or wl.ATTR_8_DESC is null
                or nvl(wl.ATTR_9_CODE,0) != atrs.ATTR_9_CODE
                or wl.ATTR_9_DESC is null
                or nvl(wl.ATTR_10_CODE,0) != atrs.ATTR_10_CODE
                or wl.ATTR_10_DESC is null
                or nvl(wl.ATTR_11_CODE,0) != atrs.ATTR_11_CODE
                or wl.ATTR_11_DESC is null
                or nvl(wl.ATTR_12_CODE,0) != atrs.ATTR_12_CODE
                or wl.ATTR_12_DESC is null
                 )
                 );
 lv_count := sql%ROWCOUNT;
 			
 COMMIT;

 LogOutput('WORKLIST', ' proc_fm_prdsync_worklist: Rows processed for attributes: ' || lv_count);
 
 
EXCEPTION
	WHEN OTHERS THEN
		LogError ('WORKLIST', 'proc_fm_prdsync_worklist: Error during update '||SQLERRM, SQLCODE);
		ROLLBACK;
		RAISE;
END proc_fm_prdsync_worklist ;

-- Emails list of released allocations that did not use a Data Collection process 
PROCEDURE proc_allocation_spy_report AS

    type n_array is table of varchar2(1024)
         index by binary_integer;
    no_dc_wldata n_array;
	lv_attachments   fmk.Tksemail.file_array@ekb_fmk := fmk.Tksemail.file_array@ekb_fmk();
	lv_ats_idx       NUMBER := 1;
    lv_sender_email  VARCHAR2(255);
    lv_from          VARCHAR2(255);
    lv_to            fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_cc            fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_bcc           fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_subject       VARCHAR2(255);
    lv_body          LONG := '';
	--lp_send          fmk.Tksemail.send@ekb_fmk;


 BEGIN

   IF rtrim(to_char(systimestamp,'DAY')) <> 'MONDAY' THEN
      LogOutput (null,'proc_allocation_spy_report: Day is ' 
      || rtrim(to_char(systimestamp,'DAY'))|| '. Report only sent on Monday ');
      RETURN;
   END IF;
    
   select
    u.user_id || ',' || rtrim(first_name) || ' '  || rtrim(last_name)  || ','
    || ALLOC_NBR || ',' || STYLE_MASTER_SKU || ',' || type || ',' || release_time as e
    BULK COLLECT INTO no_dc_wldata
     
    from
   (SELECT distinct
    wl.ALLOC_NBR, wl.STYLE_MASTER_SKU,case Af.VARIABLE_KEY when 193 then 'prior' else 'none' end as type ,status_timestamp release_time
    FROM AAM.ACTUAL_FORMAT af
     right outer join worklist wl on af.alloc_nbr=wl.alloc_nbr
     where wl.status_timestamp > systimestamp - 7.3
       and 
       wl.status_code='40'
      and 
      nvl(af.variable_key,'000') in (000,193)
            --or af.alloc_nbr is null
   ) aw
   --inner join aam.VARIABLE_HEADER vh on Aw.VARIABLE_KEY=vh.VARIABLE_KEY
   inner join aam.results_header rh on rh.allocation_nbr=aw.alloc_nbr 
   inner join aam.users u on rh.user_id=u.user_id
    ;

    logOutput(null,'proc_allocation_spy_report: ' ||
             'count='||no_dc_wldata.count()
                             ||'::last='||no_dc_wldata.last());
 
        <<attach_loop>>
        WHILE lv_ats_idx <= no_dc_wldata.count() LOOP
        
 		        lv_attachments.extend;
	            lv_attachments(lv_ats_idx).filerec := no_dc_wldata(lv_ats_idx);
		        lv_attachments(lv_ats_idx).filename := 'NoDCAllocation.csv';
			    lv_ats_idx := lv_ats_idx + 1; 

        END LOOP attach_loop;
 
    logOutput(null,'proc_allocation_spy_report: ' ||
             'count Attachment='||lv_attachments.count()
                             ||'::last='||lv_attachments.last());
 
    select 
          sys_context('USERENV', 'OS_USER') || '@'
         || sys_context('USERENV', 'SERVER_HOST') SERVER_HOST
    into 
           lv_sender_email
    from dual;
      
    lv_from := lv_sender_email;
	lv_to.EXTEND;
	lv_to(1) := 'jnfaamp@u060jdad101.kroger.com';
    lv_subject := 'JDA-Admin - ' 
                  || 'Weekly Released Allocations without Data Collection '
                  || rtrim(to_char(systimestamp,'mm-dd-yyyy hh24:mm'));
    lv_body := 'Released Allocations without Data Collection';
    
	IF no_dc_wldata.count() > 0 THEN
          BEGIN
          fmk.tksemail.send@ekb_fmk(
                         p_sender_email =>  lv_sender_email,
                         p_from => lv_from,
                         p_to => lv_to,
	                     p_cc => lv_cc,
                         p_bcc => lv_bcc,
                         p_subject => lv_subject,
                         p_body => lv_body,
						 p_attachments => lv_attachments );
           EXCEPTION
             WHEN OTHERS THEN
                logError(null,'proc_allocation_spy_report: ' ||
                'FAILED SEND **' || 'count Attachment='||lv_attachments.count()
                             ||'::last='||lv_attachments.last() ||
                 SQLERRM,SQLCODE);    	 
          END;
	    END IF;      

EXCEPTION
	WHEN OTHERS THEN
		logError(null,'proc_allocation_spy_report: ' ||
              ' Error during procedure '||SQLERRM, SQLCODE);
		ROLLBACK;
		RAISE;    -- Send the error back so that we'll get a log in the middleware.
END proc_allocation_spy_report;

-- Emails list of released allocations that did not use a Data Collection process 
PROCEDURE proc_allocation_summary_report AS

    type n_array is table of varchar2(1024)
         index by binary_integer;
    summary_wldata n_array;
	lv_attachments   fmk.Tksemail.file_array@ekb_fmk := fmk.Tksemail.file_array@ekb_fmk();
	lv_ats_idx       NUMBER := 1;
    lv_sender_email  VARCHAR2(255);
    lv_from          VARCHAR2(255);
    lv_to            fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_cc            fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_bcc           fmk.Tksemail.ARRAY@ekb_fmk := fmk.Tksemail.ARRAY@ekb_fmk();
    lv_subject       VARCHAR2(255);
    lv_body          LONG := '';
	--lp_send          fmk.Tksemail.send@ekb_fmk;


 BEGIN

   IF rtrim(to_char(systimestamp,'DAY')) <> 'MONDAY' THEN
      LogOutput (null,'proc_allocation_summary_report: Day is ' 
      || rtrim(to_char(systimestamp,'DAY'))|| '. Report only sent on Monday ');
      RETURN;
   END IF;
    
select 
    case  when usercount is null then  
     user_id || ',' || rtrim(first_name) || ' '  || rtrim(last_name)  || ','
    || ALLOC_NBR || ',' || STYLE_MASTER_SKU || ',' || PO_NBR || ',' || release_time 
    || ',' || null
    else 
    user_id || ',' || rtrim(first_name) || ' '  || rtrim(last_name)  || ','
    || ALLOC_NBR || ',' || STYLE_MASTER_SKU || ',' || PO_NBR || ',' || release_time 
    || ',' || 'Total: ' || usercount  
    end as e
    BULK COLLECT INTO summary_wldata
    from
    (
    SELECT  
      cast(wl.alloc_nbr as varchar2(8)) alloc_nbr
    , wl.STYLE_MASTER_SKU  
    , wl.po_nbr  
    , status_timestamp release_time
    , null usercount
    ,rh.user_id,first_name,last_name
    FROM AAM.worklist wl  
    inner join aam.results_header rh on rh.allocation_nbr=wl.alloc_nbr
    inner join aam.users u on rh.user_id=u.user_id  
    where wl.status_timestamp > systimestamp - 7.3
      and  wl.status_code='40'
   union 
   (select  ':' ALLOC_NBR
     , null STYLE_MASTER_SKU
     , null po_nbr 
    , null release_time
     , count(rh.allocation_nbr)  usercount
     , rh.user_id,u.first_name,u.last_name
               from AAM.results_header rh 
              inner join aam.users u on rh.user_id=u.user_id  
      inner join  AAM.worklist wl  on rh.allocation_nbr=wl.alloc_nbr
    where wl.status_timestamp > systimestamp - 7.3
      and  wl.status_code='40'
    group by rh.user_id,u.first_name,u.last_name)
    ) aw
    order by e
    ;

    logOutput(null,'proc_allocation_summary_report: ' ||
             'count='||summary_wldata.count()
                             ||'::last='||summary_wldata.last());
 
        <<attach_loop>>
        WHILE lv_ats_idx <= summary_wldata.count() LOOP
        
 		        lv_attachments.extend;
	            lv_attachments(lv_ats_idx).filerec := summary_wldata(lv_ats_idx);
		        lv_attachments(lv_ats_idx).filename := 'SummaryAllocation.csv';
			    lv_ats_idx := lv_ats_idx + 1; 

        END LOOP attach_loop;
 
    logOutput(null,'proc_allocation_summary_report: ' ||
             'count Attachment='||lv_attachments.count()
                             ||'::last='||lv_attachments.last());
 
    select 
          sys_context('USERENV', 'OS_USER') || '@'
         || sys_context('USERENV', 'SERVER_HOST') SERVER_HOST
    into 
           lv_sender_email
    from dual;
      
    lv_from := lv_sender_email;
	lv_to.EXTEND;
	lv_to(1) := 'jnfaamp@u060jdad101.kroger.com';
    lv_subject := 'JDA-Admin - ' 
                  || 'Weekly Released Allocations Summary '
                  || rtrim(to_char(systimestamp,'mm-dd-yyyy hh24:mm'));
    lv_body := 'Released Allocations Summary';
    
	IF summary_wldata.count() > 0 THEN
          BEGIN
          fmk.tksemail.send@ekb_fmk(
                         p_sender_email =>  lv_sender_email,
                         p_from => lv_from,
                         p_to => lv_to,
	                     p_cc => lv_cc,
                         p_bcc => lv_bcc,
                         p_subject => lv_subject,
                         p_body => lv_body,
						 p_attachments => lv_attachments );
           EXCEPTION
             WHEN OTHERS THEN
                logError(null,'proc_allocation_summary_report: ' ||
                'FAILED SEND **' || 'count Attachment='||lv_attachments.count()
                             ||'::last='||lv_attachments.last() ||
                 SQLERRM,SQLCODE);    	 
          END;
	    END IF;      

EXCEPTION
	WHEN OTHERS THEN
		logError(null,'proc_allocation_spy_report: ' ||
              ' Error during procedure '||SQLERRM, SQLCODE);
		ROLLBACK;
		RAISE;    -- Send the error back so that we'll get a log in the middleware.
END proc_allocation_summary_report;
--
-- PROCEDURE trig_aal_proc_control  - column defaults for aal_proc_control trigger
--
PROCEDURE trig_aal_proc_control(p_seq_id OUT AAL_PROC_CONTROL.SEQ_ID%TYPE,
                                p_status OUT AAL_PROC_CONTROL.STATUS%TYPE)
AS
BEGIN
  SELECT aal_proc_seq.NEXTVAL INTO p_seq_id FROM dual;
  
  p_status := 'O';
END trig_aal_proc_control;

PROCEDURE proc_fm_plrs_reload
AS
  sla_cnt PLS_INTEGER := 0;  
  DOW varchar(1);
BEGIN
  
  BEGIN
    SELECT COUNT(*)
      INTO sla_cnt
      FROM SLA_SKU_LOC_AUTH;
  EXCEPTION
    WHEN OTHERS THEN 
      LogError('PROC_FM_PLRS_RELOAD', ' proc_fm_plrs_reload : Error occurred selecting data-'|| SQLERRM,SQLCODE);
      RAISE;
  END;
  
  --get day of week so we always do a rebuild on Sunday
  BEGIN
    SELECT to_char(SYSDATE, 'd') into DOW FROM dual;
  EXCEPTION
    WHEN OTHERS THEN
      LogError('PROC_FM_PLRS_RELOAD', ' proc_fm_plrs_reload : Error occurred in get DOW - '|| SQLERRM,SQLCODE);
      ROLLBACK;
      RAISE;
   END;
    
  IF sla_cnt >= 10000 OR DOW = 1 THEN
    LOCK TABLE FM_AALRST IN EXCLUSIVE MODE;
    
    BEGIN
      DELETE FROM SLA_SKU_LOC_AUTH;
    EXCEPTION
      WHEN OTHERS THEN 
        LogError('PROC_FM_PLRS_RELOAD', ' proc_fm_plrs_reload : Error occurred deleting SLA data-'|| SQLERRM,SQLCODE);
        RAISE;
    END;
    
    COMMIT;
    
    AAMFM.PLRS_RELOAD;
    AAM.GRANT_LIST_PLAN;
    
  ELSE
    LogOutput('PROC_FM_PLRS_RELOAD', ' proc_fm_plrs_reload : Skipping processing today');
  END IF;
  
END proc_fm_plrs_reload;

END Allocmagic;	/*end of package*/