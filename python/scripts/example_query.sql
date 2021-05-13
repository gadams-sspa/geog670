select val, st_geomfromtext(geom, 4269) AS geom
from test_plr(
	$$select ST_X(geom) as x, ST_Y(geom) as y, AVG(depth_towl_ft) as z, datetime
			from public.usgs_wl_data
      where 
(	   (datetime, datetime)
		OVERLAPS 
	  ( TO_TIMESTAMP('2021-05-12 22:00:00', 'YYYY-MM-DD HH24:MI:SS' ), interval '5 minutes' )
)
GROUP BY x, y, datetime
	  $$
) as geom;