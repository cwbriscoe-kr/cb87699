SET NOCOUNT ON         ;
WITH 
[ckbe3_floorplan_key_15wks_vw] as (
-- Final view offers dbkeys to junction the latest
-- planograms to the latest floorplans and sect_mult_flag
-- * modified                                                 
-- * 2011-02-23 Glenn Mavor - add filter "and flr_qlvl_1.DBStatus IN (1, 2, 5)" to outer where clause 
-- * 2015-08-19 Glenn Mavor - add DBDateEffectiveTo date to prevent summing overlapping live plans
-- * 2015-12-22 Glenn Mavor - removed DBDateEffectiveTo date as live plans were being excluded
select flr_qlvl_1.dbkey DBkey
          ,flr_eff_date 
		  ,flr_ver_key
          ,GLN Loc_nbr --,flr_qlvl_1.[DBDateEffectiveFrom] DateFrom,flr_qlvl_1.DBDateEffectiveTo DateTo
from
	(
select max(flr_qlvl_0.DBDateEffectiveFrom) flr_eff_date
		  ,flr_ver_key
	  from 
		  -- level 0 inner view determines version keys for currently joined
		  -- planograms and floorplans, and carries forward section mult flag
		  (select distinct
			   ix_flr_floorplan.[DBVersionKey] flr_ver_key         
			  from CKB.dbo.ix_flr_floorplan ix_flr_floorplan (NOLOCK)
		   ) vk
		  ,CKB.dbo.ix_flr_floorplan flr_qlvl_0 (NOLOCK)
 	where vk.flr_ver_key=flr_qlvl_0.[DBVersionKey] 
	  and (flr_qlvl_0.DBDateEffectiveFrom is not null
	       and flr_qlvl_0.DBDateEffectiveFrom <= current_timestamp + 15 * 7)
	  and isNull(flr_qlvl_0.DBDateEffectiveTo, current_timestamp + 15 * 7) >= current_timestamp + 15 * 7
      and flr_qlvl_0.DBStatus IN (1, 2, 5) 
	group by  flr_ver_key 
	) vklive
	,CKB.dbo.ix_flr_floorplan  flr_qlvl_1 (NOLOCK)
where vklive.[flr_ver_key]=flr_qlvl_1.[DBVersionKey]
  and vklive.flr_eff_date=flr_qlvl_1.[DBDateEffectiveFrom] 
  and flr_qlvl_1.DBStatus IN (1, 2, 5)
)
 ,[ckbe3_floorplan_key_curr_vw] as (
-- Final view offers dbkeys to junction the latest
-- planograms to the latest floorplans and sect_mult_flag
-- * modified                                                 
-- * 2011-02-23 Glenn Mavor - add filter "and flr_qlvl_1.DBStatus IN (1, 2)" to outer where clause 
-- * 2015-08-19 Glenn Mavor - add DBDateEffectiveTo date to prevent summing overlapping live plans
-- * 2015-12-22 Glenn Mavor - removed DBDateEffectiveTo date as live plans were being excluded
select flr_qlvl_1.dbkey DBkey
          ,flr_eff_date 
		  ,flr_ver_key
          ,GLN Loc_nbr --,flr_qlvl_1.[DBDateEffectiveFrom] DateFrom,flr_qlvl_1.DBDateEffectiveTo DateTo
from
	(
select max(flr_qlvl_0.DBDateEffectiveFrom) flr_eff_date
		  ,flr_ver_key
	  from 
		  -- level 0 inner view determines version keys for currently joined
		  -- planograms and floorplans, and carries forward section mult flag
		  (select distinct
			   ix_flr_floorplan.[DBVersionKey] flr_ver_key         
			  from CKB.dbo.ix_flr_floorplan ix_flr_floorplan (NOLOCK)
		   ) vk
		  ,CKB.dbo.ix_flr_floorplan flr_qlvl_0 (NOLOCK)
 	where vk.flr_ver_key=flr_qlvl_0.[DBVersionKey] 
	 and (flr_qlvl_0.DBDateEffectiveFrom is not null
	      and flr_qlvl_0.DBDateEffectiveFrom <= current_timestamp + 15 * 7
        )
	  --and isNull(flr_qlvl_0.DBDateEffectiveTo, current_timestamp + 15 * 7) >= current_timestamp
      and flr_qlvl_0.DBStatus IN (1, 2, 5) 
	group by  flr_ver_key 
	) vklive
	,CKB.dbo.ix_flr_floorplan  flr_qlvl_1 (NOLOCK)
where vklive.[flr_ver_key]=flr_qlvl_1.[DBVersionKey]
  and vklive.flr_eff_date=flr_qlvl_1.[DBDateEffectiveFrom] 
  and flr_qlvl_1.DBStatus IN (1, 2, 5) 
)
 , [ckbe3_section_planogram_15wks_vw] AS (
 -- =============================================
-- Author:		Glenn Mavor
-- Create date: 07/11/08
-- Description:	View creating virtual junction table
--              between the latest planogram
--              and latest floorplan
-- Execution:	Used in generating snapshot for 
--              E3 Replenishment
-- =============================================
-- Modifications:
--   gsm 01/18/09 correct key retrieval for current and new planogram
--
-- Final view offers dbkeys to junction the latest
-- planograms to the latest floorplans and sect_mult_flag
select pog_qlvl_1a.dbkey dbnewplanogramkey
      ,pog_qlvl_1b.dbkey dboldplanogramkey
--,pog_ver_key,pog_eff_date_max,pog_eff_date_min
from
	-- level 1 inner view determines the latest live dates on
	-- planograms and floorplans linking them to version keys
	(select max(pog_qlvl_0.DBDateEffectiveFrom) pog_eff_date_max
          ,min(pog_qlvl_0.DBDateEffectiveFrom) pog_eff_date_min
		  ,vk.pog_ver_key
         -- ,pog_qlvl_0.dbkey  dbkey
	  from 
		  -- level 0 inner view determines version keys for currently joined
		  -- planograms and floorplans, and carries forward section mult flag
		  (select distinct
			  ix_spc_planogram.[DBVersionKey] pog_ver_key   
			  from ckbe3_floorplan_key_curr_vw ckbe3_floorplan_key_curr_vw (NOLOCK)
				  ,CKB.dbo.ix_flr_section ix_flr_section (NOLOCK)
				  ,CKB.dbo.ix_spc_planogram  ix_spc_planogram (NOLOCK)
			  where ix_flr_section.dbparentplanogramkey = ix_spc_planogram.dbkey
				and ckbe3_floorplan_key_curr_vw.DBkey = ix_flr_section.dbparentfloorplankey
		   ) vk
		   -- 
		  ,CKB.dbo.ix_spc_planogram pog_qlvl_0 (NOLOCK)
	where vk.pog_ver_key=pog_qlvl_0.[DBVersionKey] 
	  and pog_qlvl_0.DBDateEffectiveFrom is not null
	  and pog_qlvl_0.DBDateEffectiveFrom <= current_timestamp + 15 * 7
     and pog_qlvl_0.DBStatus IN (1, 2, 5) 
	group by pog_ver_key
            --,pog_qlvl_0.dbkey
	) vklive
    -- 
	,CKB.dbo.ix_spc_planogram  pog_qlvl_1a (NOLOCK)
	,CKB.dbo.ix_spc_planogram  pog_qlvl_1b (NOLOCK)
where vklive.[pog_ver_key]=pog_qlvl_1a.[DBVersionKey]
  and vklive.[pog_ver_key]=pog_qlvl_1b.[DBVersionKey]
  and vklive.pog_eff_date_max=pog_qlvl_1a.[DBDateEffectiveFrom]
  and vklive.pog_eff_date_min=pog_qlvl_1b.[DBDateEffectiveFrom]
 )
 , [ckbe3_floorsection_keys_vw] AS (
 SELECT [DBParentFloorplanKey]
       ,[DBParentPlanogramKey]
       ,[Flag1]
   FROM [CKB].[dbo].[ix_flr_section]
 group by [DBParentFloorplanKey]
       ,[DBParentPlanogramKey]
       ,[Flag1]
 having isNull([Flag1],0) = 0
 union all (
 SELECT [DBParentFloorplanKey]
       ,[DBParentPlanogramKey]
       ,[Flag1]
   FROM [CKB].[dbo].[ix_flr_section]
 where [Flag1] = 1)
 )
 SELECT	 SkuNbr
       , LocNbr
       , sum(Facings)  Facings
       , sum(Capacity) Capacity
 	  , sum(PosReplMin) PosReplMin  
 	  , min(FlowCode)   FlowCode
 FROM (
 	SELECT	ISNULL(CAST(ix_spc_product.PartID AS char(8)), ' ') AS SkuNbr
  , coalesce(CAST(SUBSTRING(ikbe3_floorplan_key_curr_vw.Loc_nbr, 1, 5) AS char(5)),CAST(SUBSTRING(strdata.Loc_Nbr, 1, 5)AS char(5)),' ') AS LocNbr
	, ix_spc_planogram.Department                       
	, isNull(ikbe3_floorsection_keys_vw.Flag1,0)                         as sect_mult_flag
	, ISNULL(CAST(
			case 
			when ix_spc_position.Orientation in (0,4,6,8,10,12,16,18,22) then
				case 
				when ix_spc_position.MerchStyle = 1 then
					ix_spc_product.TrayNumberWide * ix_spc_position.Facings
				when ix_spc_position.MerchStyle = 2 then
					ix_spc_product.CaseNumberWide * ix_spc_position.Facings
				else
					Facings
				end
			when ix_spc_position.Orientation in (1,3,7,9,13,15,19,21) then
				case 
				when ix_spc_position.MerchStyle = 1 then
					ix_spc_product.TrayNumberHigh * ix_spc_position.Facings
				when ix_spc_position.MerchStyle = 2 then
					ix_spc_product.CaseNumberHigh * ix_spc_position.Facings
				else
					Facings
				end 
			else
				case 
				when ix_spc_position.MerchStyle = 1 then
					ix_spc_product.TrayNumberDeep * ix_spc_position.Facings
				when ix_spc_position.MerchStyle = 2 then
					ix_spc_product.CaseNumberDeep * ix_spc_position.Facings
				else
					Facings
				end
			end  AS INT), 0) AS Facings,flr_eff_date
	, ISNULL(CAST(ix_spc_position.Capacity AS INT), 0) AS Capacity
	, isNull(CAST(
      case when ix_spc_position.MerchStyle=3 then 1
			 when ix_spc_position.MerchStyle=1 
				  then 
				  case when ix_spc_product.TrayNumberDeep=1 
					   then ix_spc_position.HFacings*ix_spc_position.VFacings*ix_spc_product.Traynumberwide*ix_spc_product.Traynumberhigh
					   else ix_spc_position.HFacings*ix_spc_position.VFacings*((ix_spc_product.Traynumberwide*ix_spc_product.Traynumberhigh)+ix_spc_product.Traynumberwide)  
				  end
			 when ix_spc_position.MerchStyle=2
				  then 
				  case when ix_spc_product.Casenumberdeep=1
					   then ix_spc_position.HFacings*ix_spc_position.VFacings*ix_spc_product.Casenumberwide*ix_spc_product.Casenumberhigh 
					   else ix_spc_position.HFacings*ix_spc_position.VFacings*((ix_spc_product.Casenumberwide*ix_spc_product.Casenumberhigh)+ix_spc_product.Casenumberwide)
				  end
			 else case when (ix_spc_position.DFacings+ix_spc_position.Zcapnum)=1
					   then ix_spc_position.HFacings*(ix_spc_position.VFacings+ix_spc_position.Ycapnum)
					   else (ix_spc_position.HFacings*(ix_spc_position.VFacings+ix_spc_position.Ycapnum))+ix_spc_position.HFacings
				  end
		  end  AS INT), 0)		  AS PosReplMin
	,  ix_spc_product.Desc6                           AS FlowCode
	FROM         CKB.dbo.ix_spc_position AS ix_spc_position WITH (NOLOCK) 
				 INNER JOIN
				  CKB.dbo.ix_spc_product AS ix_spc_product WITH (NOLOCK) 
				  ON ix_spc_position.DBParentProductKey = ix_spc_product.DBKey 
				 INNER JOIN
				  CKB.dbo.ix_spc_planogram AS ix_spc_planogram WITH (NOLOCK) 
				  ON ix_spc_position.DBParentPlanogramKey = ix_spc_planogram.DBKey 
				 INNER JOIN
				  [ckbe3_section_planogram_15wks_vw] AS ikbe3_section_planogram_15wks_vw WITH (NOLOCK) 
				  ON ix_spc_planogram.DBKey = ikbe3_section_planogram_15wks_vw.dbnewplanogramkey 
				 INNER JOIN
				  [ckbe3_floorsection_keys_vw] as ikbe3_floorsection_keys_vw with(NOLOCK) 
				  ON ikbe3_floorsection_keys_vw.dbparentplanogramkey = ikbe3_section_planogram_15wks_vw.dboldplanogramkey 
				 INNER JOIN
				  [ckbe3_floorplan_key_curr_vw] AS ikbe3_floorplan_key_curr_vw WITH (NOLOCK) 
				  ON ikbe3_floorplan_key_curr_vw.DBkey = ikbe3_floorsection_keys_vw.dbparentfloorplankey
	             LEFT OUTER JOIN
	              (select dbparentfloorplankey,Desc1 as Loc_Nbr
	               from CKB.dbo.ix_str_store_floorplan as ix_str_store_floorplan
	                   ,CKB.dbo.ix_str_store as ix_str_store
	                where ix_str_store.dbkey = ix_str_store_floorplan.dbparentstorekey) strdata
    			  ON ikbe3_floorplan_key_curr_vw.DBkey = strdata.dbparentfloorplankey
	WHERE ix_spc_planogram.DBStatus IN (1, 2, 5) 
	AND CAST(ix_spc_product.Desc6 AS varchar(3)) IN ('DTS', 'RMA','WHP','ALC') 
	AND ix_spc_product.Value14 IN (20, 30) 
  AND ix_spc_product.Desc45  = '87'                                                                                                                     
  AND ix_spc_product.PartID  > ' '                                                            
  AND coalesce(CAST(SUBSTRING(ikbe3_floorplan_key_curr_vw.Loc_nbr, 1, 5) AS char(5))
               ,CAST(SUBSTRING(strdata.Loc_Nbr, 1, 5)AS char(5)),' ') 
               between '00000' AND '99999'                                                            
 	) flrsecpogjoin
 group by SkuNbr
       , LocNbr
order by skuNbr,LocNbr; 