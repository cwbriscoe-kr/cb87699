select
       vd1.vndr_nbr
      ,vd1.vndr_nm
      ,vd1.edi_flg
      ,vd1.vndr_typ_cd
      ,vd1.imp_flg
      ,vd1.corp_ref_vndr_nbr
      ,coalesce(va2.addr_type_cd, ' ') as addr_type_cd
      ,coalesce(va2.addr_name, ' ') as addr_name
      ,coalesce(va2.addr_street_nbr, ' ') as addr_street_nbr
      ,coalesce(va2.addr_city_name, ' ') as addr_city_name
      ,coalesce(va2.st_cd, ' ') as addr_st_cd
      ,coalesce(va2.zip_cd, ' ') as addr_zip_cd
      ,coalesce(va2.addr_ctry_cd, ' ') as addr_country_cd
      ,coalesce(va2.tlphne_nbr, ' ') as telephone_nbr
  from vd1_vndr_dtl vd1
  left outer join va2_vndr_loc_addr va2 on va2.vndr_nbr = vd1.vndr_nbr
 where vd1.rec_stat_cd = '01'
  with ur;

select count(*)
  from vd1_vndr_dtl
 where rec_stat_cd = '01'
  with ur;