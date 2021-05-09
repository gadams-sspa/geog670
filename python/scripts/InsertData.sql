-- Author: Glen Adams
-- TODO: Move this logic into RealtimeDataUpdate.py
CREATE TABLE IF NOT EXISTS realtime_test.usgs_wl_data_temp (
	uid varchar NOT NULL,
	agency varchar NULL,
	site_no int8 NULL,
	datetime date NULL,
	tz_cd varchar NULL,
	depth_towl_ft numeric NULL,
	latitude numeric NULL,
	longitude numeric NULL
);

COPY realtime_test.usgs_wl_data_temp(uid, agency, site_no, datetime, tz_cd, depth_towl_ft, latitude, longitude)
FROM '/home/postgres/temp_realtime_wl/edited_data.csv' DELIMITER ',' CSV HEADER;

insert into realtime_test.usgs_wl_data
select uid, agency, site_no, datetime, tz_cd, depth_towl_ft, latitude, longitude, ST_SetSRID(ST_MakePoint("longitude"::double precision, "latitude"::double precision),4269)
from realtime_test.usgs_wl_data_temp
on conflict on constraint usgs_wl_data_pkey
do nothing;

drop table if exists realtime_test.usgs_wl_data_temp;