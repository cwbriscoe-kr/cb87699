with stats as (
SELECT OBJECT_NAME(object_id) AS [ObjectName]
      ,[name] AS [StatisticName]
      ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
)
select *
  from stats
 where ObjectName like 'ix_%'
 order by ObjectName
 ;