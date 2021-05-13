-- Adjust to accept PostGIS geometry
select st_geomfromtext(geom, 4269)
from test_plr(
	$$select ST_X(geom) as x, ST_Y(geom) as y, AVG(depth_towl_ft) as z, datetime
			from realtime_test.usgs_wl_data
      where 
(	   (datetime, datetime)
		OVERLAPS 
	  ( TO_TIMESTAMP('2020-03-06 09:15:00', 'YYYY-MM-DD HH24:MI:SS' ), interval '7.5 minutes' )
)
GROUP BY x, y, datetime
	  $$
) as geom;