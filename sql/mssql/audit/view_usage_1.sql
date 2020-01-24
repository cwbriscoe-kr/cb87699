DECLARE     @FindSql nvarchar(max) = 'kr_spc_product_vw';
SELECT 
    /* cp.*, ct.* */
    cp.objtype AS [Type],
    cp.refcounts AS ReferenceCount,
    cp.usecounts AS UseCount,
    cp.size_in_bytes / 1024 AS SizeInKB,
    db_name(ct.dbid) AS [Database],
    CAST(pt.query_plan as xml) as QueryPlan
FROM sys.dm_exec_cached_plans cp
OUTER APPLY sys.dm_exec_text_query_plan(plan_handle, 0, -1) pt
OUTER APPLY sys.dm_exec_sql_text(plan_handle) AS ct
WHERE (ct.text LIKE '%' + @FindSql + '%') OR (pt.query_plan LIKE '%' + @FindSql + '%')
ORDER BY cp.usecounts DESC;