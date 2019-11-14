with systables as (
select name, object_id, schema_id, create_date
  from sys.tables
  union
select name, object_id, schema_id, create_date
  from sys.views
), schematables as (
select table_catalog as catalog
      ,table_schema as schma
      ,table_name as name
      ,table_type as type
  from information_schema.tables
), tbls as (
select schma.*
      ,syst.object_id
      ,syst.schema_id
      ,syst.create_date
      ,lower(schma.name) as name_lower
      ,datediff(day, create_date, getdate()) as days_old
  from schematables schma left join
       systables syst on (schma.name = syst.name)
), rpt as (
select cast('' as nvarchar(128)) as env
      ,schma
      ,name
      ,type
      ,days_old
      ,name_lower
  from tbls
 where (schma not in ('dbo','jdacustom')
    or name_lower like '%tmp%'
    or name_lower like '%temp%'
    or name_lower like '%backup%'
    or name_lower like '%bkup%'
    or name_lower like '%bkp%'
    or name_lower like '%[0-9]%')
   and days_old > 30
   and name_lower not like '%point3d'
   and name_lower not like 'csg_tmp_getmovement%'
)
select * into zzz_rpt_tmp_db_objs from rpt order by schma, name