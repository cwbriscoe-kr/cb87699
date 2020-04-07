--This query is used to determine which old allocation members need to be purged manually in
--order to reclaim disk space.  Currently E3 does not clean up the members properly.  First run the following command:
--DSPFD FILE(E3SFMI/E3SFCS) TYPE(*MBRLIST) OUTPUT(*OUTFILE) OUTFILE(CB87699/FCSLIST)
--Next execute the query below which will list members that no longer have a header in e3spact.  Then delete the members from
--the following files in order:
--RMVM FILE(E3SFMI/E3SFCSZ2) MBR(M0016673)
--RMVM FILE(E3SFMI/E3SFCS) MBR(M0016673)

select MLNAME, MLSIZE
   from cb87699.fcslist
 where cast(substr(mlname, 2, 7) as decimal) not in (select pcntrl from e3sfmi.e3spact)
order by mlsize desc