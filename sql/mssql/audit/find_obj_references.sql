SELECT sys.objects.object_id, sys.schemas.name AS [Schema], sys.objects.name AS Object_Name, sys.objects.type_desc AS [Type]
FROM sys.sql_modules (NOLOCK) 
INNER JOIN sys.objects (NOLOCK) ON sys.sql_modules.object_id = sys.objects.object_id 
INNER JOIN sys.schemas (NOLOCK) ON sys.objects.schema_id = sys.schemas.schema_id
WHERE sys.sql_modules.definition COLLATE SQL_Latin1_General_CP1_CI_AS LIKE '%Desc37%' ESCAPE '\'
  AND sys.sql_modules.definition COLLATE SQL_Latin1_General_CP1_CI_AS LIKE '%ix_spc_planogram%' ESCAPE '\'
ORDER BY sys.schemas.name, sys.objects.name