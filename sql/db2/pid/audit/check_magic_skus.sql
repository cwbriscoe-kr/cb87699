select fi1.ft_lvl01_cd
      ,fi1.ft_lvl02_cd
      ,fi1.ft_lvl03_cd
      ,fi1.ft_lvl04_cd
      ,fi1.ft_lvl05_cd
      ,fi1.ft_lvl06_cd
      ,fi1.ft_lvl07_cd
      ,fi1.ft_lvl08_cd
      ,fi1.ft_lvl09_cd
      ,is2.sku_typ_cd
      ,is2.sku_nbr
      ,is2.desc_lng_txt
  from prd.fi1_ft_itm  fi1
      ,prd.is2_itm_sku is2
 where fi1.itm_nbr = is2.itm_nbr
   and is2.sku_nbr in (
'00001847'
,'00003117'
,'00004244'
,'00004817'
,'00005517'
,'00006217'
,'00006705'
,'00007047'
,'00007504'
,'00007917'
,'00008617'
,'00009317'
,'00011617'
,'00012317'
,'00013017'
,'00013314'
,'00014113'
,'00014717'
,'00015417'
,'00015813'
,'00016117'
,'00016612'
,'00017411'
,'00017817'
,'00018517'
,'00019217'
,'00021517'
,'00021616'
,'00022217'
,'00022415'
,'00023917'
,'00024617'
,'00025317'
,'00026017'
,'00026505'
,'00027304'
,'00027717'
,'00028103'
,'00028417'
)
order by fi1.ft_lvl01_cd
        ,fi1.ft_lvl02_cd
        ,fi1.ft_lvl03_cd
        ,fi1.ft_lvl04_cd
        ,fi1.ft_lvl05_cd
        ,fi1.ft_lvl06_cd
        ,fi1.ft_lvl07_cd
        ,fi1.ft_lvl08_cd
        ,fi1.ft_lvl09_cd
        ,is2.sku_nbr
for fetch only with ur
;