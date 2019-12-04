with perf as (
select 'ix_flr_performance' as name
      ,count(*) as reccnt
      ,max(dbkey) as maxkey
      ,IDENT_CURRENT('dbo.ix_flr_performance') as nextkey 
  from dbo.ix_flr_performance
), sect as (
select 'ix_flr_section' as name
      ,count(*) as reccnt
      ,max(dbkey) as maxkey
      ,IDENT_CURRENT('dbo.ix_flr_section') as nextkey 
  from dbo.ix_flr_section
), fixt as (
select 'ix_flr_fixture' as name
      ,count(*) as reccnt
      ,max(dbkey) as maxkey
      ,IDENT_CURRENT('dbo.ix_flr_fixture') as nextkey 
  from dbo.ix_flr_section
)
select * from perf
 union
select * from sect
 union
select * from fixt
;