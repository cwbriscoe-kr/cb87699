with live as (
select DBKey
      ,PartID as SkuNbr
      ,ID as CaseUPC
      ,UPC as BaseUPC
  from ckb.dbo.ix_spc_product prod with (nolock)
 where PartID is not null
   and PartID > '00000000'
   and exists (
       select top(1) 1
         from ckb.dbo.ix_spc_position posi
        where posi.DBParentProductKey = prod.DBKey
       )
), stage as (
select SKU as SkuNbr
      ,ID as CaseUPC
      ,UPC as BaseUPC
  from ckb.jdacustom.csg_stg_product
 where SKU is not null
)
select top(100) live.DBKey
               ,live.SkuNbr
               ,live.CaseUPC as OldCaseUPC
               ,stage.CaseUPC  as NewCaseUPC
               ,live.BaseUPC as OldBaseUPC
               ,stage.BaseUPC as NewBaseUPC
  from stage left join live on (stage.SkuNbr = live.SkuNbr)
 where DBKey is not null
   and (live.CaseUPC != stage.CaseUPC
    or  live.BaseUPC != stage.BaseUPC)
 order by live.SkuNbr