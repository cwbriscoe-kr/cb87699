with raw as (
select objects.name as tblname
     ,coalesce(indexes.name, '') as idxname
     ,dm_db_index_usage_stats.user_lookups
     ,dm_db_index_usage_stats.user_seeks
     ,dm_db_index_usage_stats.user_scans
     ,dm_db_index_usage_stats.user_updates
     ,indexes.is_primary_key
     ,indexes.is_unique
from sys.dm_db_index_usage_stats
inner join sys.objects on dm_db_index_usage_stats.OBJECT_ID = objects.OBJECT_ID
inner join sys.indexes on indexes.index_id = dm_db_index_usage_stats.index_id and dm_db_index_usage_stats.OBJECT_ID = indexes.OBJECT_ID
where dm_db_index_usage_stats.database_id = DB_ID('CKB')
)
select tblname, idxname, user_lookups, user_seeks, user_scans, user_updates
  from raw
where user_lookups = 0
  and user_seeks = 0
  and user_scans = 0
  and is_primary_key = 0
  and is_unique = 0
  and idxname not like 'ix_%'
order by tblname, idxname
;