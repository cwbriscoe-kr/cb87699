USE Master
GO
SELECT 
    UseCounts, RefCounts,CacheObjtype, ObjType, DB_NAME(dbid) as DatabaseName, SQL
FROM syscacheobjects
WHERE SQL LIKE '%kr_spc_product_vw%'
ORDER BY dbid,usecounts DESC,objtype