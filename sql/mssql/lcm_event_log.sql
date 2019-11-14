select top(1000) *
from ix_sys_event_log
where dbtime > DATEADD(day, -1, GETDATE())
  and EventID in (50052001,50052002,50052003)
--    and description like '%Lifecycle%'