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