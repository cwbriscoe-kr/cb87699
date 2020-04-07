select vndr_nbr as magvnd
         ,ord_prs_days + trnst_days as maglt
  from prd.vd1_vndr_dtl;