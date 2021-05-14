select depth_towl_ft, st_geomfromtext(geom, 4269) AS geom
from plr_contour(
	$$select DISTINCT ON (x, y) ST_X(geom) as x, ST_Y(geom) as y, AVG(depth_towl_ft) as z, datetime
			from public.usgs_wl_data
      where 
(	   (datetime, datetime)
		OVERLAPS 
	  ( TO_TIMESTAMP('2021-05-14 00:00:00', 'YYYY-MM-DD HH24:MI:SS' ), interval '30 minutes' )
) AND depth_towl_ft IS NOT NULL
GROUP BY x, y, datetime
	  $$
) as geom;