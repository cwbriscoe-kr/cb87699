
select vvndr as ssvnd
         ,substr(vvndr,2,6)  || 
         case substr(vvndr,8,1)
             when '0' then '00'
             when ' ' then '00'
             when 'A' then '01'
             when 'B' then '02'
             when 'C' then '03'
             when 'D' then '04'
             when 'E' then '05'
             when 'F' then '06'
             when 'G' then '07'
             when 'H' then '08'
             when 'I' then '09'
             when 'J' then '10'
             when 'K' then '11'
             when 'L' then '12'
             when 'M' then '13'
             when 'N' then '14'
             when 'O' then '15'
             when 'P' then '16'
             when 'Q' then '17'
             when 'R' then '18'
             when 'S' then '19'
             when 'T' then '20'
             when 'U' then '21'
             when 'V' then '22'
             when 'W' then '23'
             when 'X' then '24'
             when 'Y' then '25'
             when 'Z' then '26'
             else 'XX'
           end as magvnd
          ,vltqtd as E3LT
  from e3sfmi.e3ssrcb
where vdcid = 'NONE'
    and substr(vvndr,1,1) = 'S'
group by vvndr, vltqtd
order by vvndr, vltqtd
