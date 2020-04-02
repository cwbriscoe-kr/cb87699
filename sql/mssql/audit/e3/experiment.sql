SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
with floorplans as (
select g.email as LocNbr 
      ,isnull(g.flag3,0) as str_converted 
      ,isnull(g.flag5,0) as str_ready_for_test
      ,e.dbdateeffectivefrom as fp_live_date
      ,e.dbdateeffectiveto as fp_end_date
      ,g.dbkey as str_key
      ,e.dbkey as flr_key
      ,e.dbversionkey as flr_versionkey
      ,e.dbstatus as flr_status
  from ix_flr_floorplan e with (nolock)
  join ix_str_store_floorplan f with (nolock) on f.dbparentfloorplankey = e.dbversionkey
  join ix_str_store g with (nolock) on g.dbkey = f.dbparentstorekey 
 where e.dbstatus in (1,2,7)
   and g.email between '00000' and '99999'
), planograms as (
select floorplans.*
      ,plano.DBKey as pog_key
  from floorplans
  join ix_flr_performance flrperf with (nolock)
    on flrperf.DBParentFloorplanKey = floorplans.flr_key
  join ix_spc_planogram plano with (nolock)
    on plano.DBKey = flrperf.DBParentPlanogramKey
 where plano.DBStatus in (1,3,5)
), products as (
select pogs.*
      ,prod.PartID as SkuNbr
      ,isnull(cast(
       case 
       when pos.Orientation in (0,4,6,8,10,12,16,18,22) then
            case 
            when pos.MerchStyle = 1 then
                 prod.TrayNumberWide * pos.Facings
            when pos.MerchStyle = 2 then
                 prod.CaseNumberWide * pos.Facings
            else pos.Facings end
       when pos.Orientation in (1,3,7,9,13,15,19,21) then
            case 
            when pos.MerchStyle = 1 then
                 prod.TrayNumberHigh * pos.Facings
            when pos.MerchStyle = 2 then
                 prod.CaseNumberHigh * pos.Facings
            else pos.Facings end 
       else
            case 
            when pos.MerchStyle = 1 then
                 prod.TrayNumberDeep * pos.Facings
            when pos.MerchStyle = 2 then
                 prod.CaseNumberDeep * pos.Facings
            else pos.Facings end
       end as int),0) as Facings
      ,isnull(cast(pos.Capacity as int),0) as Capacity
      ,isnull(cast(
       case when pos.MerchStyle = 3 then 1
            when pos.MerchStyle = 1 then 
                 case 
                 when prod.TrayNumberDeep = 1 then
                      pos.HFacings * pos.VFacings * prod.Traynumberwide * prod.Traynumberhigh
                 else pos.HFacings * pos.VFacings * ((prod.Traynumberwide * prod.Traynumberhigh) + prod.Traynumberwide) end
            when pos.MerchStyle = 2 then 
                 case 
                 when prod.Casenumberdeep = 1 then
                      pos.HFacings * pos.VFacings * prod.Casenumberwide * prod.Casenumberhigh 
                 else pos.HFacings * pos.VFacings * ((prod.Casenumberwide * prod.Casenumberhigh) + prod.Casenumberwide) end
            else 
                 case 
                 when (pos.DFacings + pos.Zcapnum) = 1 then
                      pos.HFacings * (pos.VFacings + pos.Ycapnum)
                 else pos.HFacings * (pos.VFacings + pos.Ycapnum) + pos.HFacings end
       end as int),0) as PosReplMin
      ,prod.Desc6 as FlowCode
  from planograms pogs
  join ix_spc_position pos with (nolock)
    on pos.DBParentPlanogramKey = pogs.pog_key
  join ix_spc_product prod with (nolock)
    on prod.DBKey = pos.DBParentProductKey
 where prod.Value14 in ('20','30')
   and prod.Desc45 = '87'
   and prod.Desc6 in ('DTS','RMA','WHP','ALC') 
   and prod.PartID > space(8)
), current_ranked as (
select rank() over (partition by flr_versionkey, SkuNbr, LocNbr order by fp_live_date desc, flr_key desc) daterank
      ,'C' as TypeFlag
      ,prod.*
  from products prod
where prod.fp_live_date <= current_timestamp
), future_ranked as (
select rank() over (partition by flr_versionkey, SkuNbr, LocNbr order by fp_live_date desc, flr_key desc) daterank
      ,'F' as TypeFlag
      ,prod.*
  from products prod
 where prod.fp_live_date <= dateadd(day, 15*7, current_timestamp)
   and prod.fp_live_date  > current_timestamp
   and prod.fp_end_date >= dateadd(day, 15*7, current_timestamp)
), ranked as (
select * from current_ranked where daterank = 1
 union
select * from future_ranked where daterank = 1
), results as (
select SkuNbr
      ,LocNbr
      ,TypeFlag
      ,sum(Facings) as Facings
      ,sum(Capacity) as Capacity
      ,sum(PosReplMin) as PosReplMin
      ,min(FlowCode) as FlowCode
  from ranked
 group by SkuNbr, LocNbr, TypeFlag
)
--select * from ranked where daterank > 1;
--select * from ranked where SkuNbr in ('76938443','01488647') and LocNbr = '00210' ;
select top 1000 * 
  from results
 where LocNbr = '00210'
   and SkuNbr in ('76938443','01488647')
 order by SkuNbr, LocNbr, TypeFlag
OPTION(USE HINT('ENABLE_PARALLEL_PLAN_PREFERENCE'), RECOMPILE)