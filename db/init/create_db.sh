#!/bin/sh

set -e

# Perform all actions as $POSTGRES_USER
export PGUSER="$POSTGRES_USER"

# Create the 'template_postgis' template db
"${psql[@]}" <<- 'EOSQL'
CREATE DATABASE template_postgis IS_TEMPLATE true;
EOSQL

# Load PostGIS into both template_database and $POSTGRES_DB
for DB in template_postgis "$POSTGRES_DB"; do
	echo "Loading PostGIS extensions into $DB"
	"${psql[@]}" --dbname="$DB" <<-'EOSQL'
		CREATE EXTENSION IF NOT EXISTS postgis;
		CREATE EXTENSION IF NOT EXISTS plr;
		CREATE TABLE usgs_wl_data (
			uid varchar NOT NULL,
			agency varchar NULL,
			site_no int8 NULL,
			datetime timestamp NULL,
			tz_cd varchar NULL,
			depth_towl_ft numeric NULL,
			lat numeric NULL,
			lon numeric NULL,
			geom geometry(POINT, 4269) NULL,
			CONSTRAINT usgs_wl_data_pkey PRIMARY KEY (uid)
		);

		CREATE TABLE wl_contour (
			depth_towl_ft DOUBLE PRECISION,
			geom geometry(MULTILINESTRING, 4269) NULL
		);

		-- Type required for the 
		CREATE TYPE gw_contour AS (depth_towl_ft DOUBLE PRECISION, geom TEXT);

		-- Create Function to build geom
		CREATE OR REPLACE FUNCTION fn_usgs_wl_data_build_geom()
		RETURNS trigger
		AS $$
			BEGIN
				UPDATE usgs_wl_data SET 
					geom = ST_SetSRID(ST_MakePoint(lon, lat), 4269)
				WHERE uid=NEW.uid;
				RETURN NULL; -- result is ignored since this is an AFTER trigger
			END;
		$$
		LANGUAGE 'plpgsql';

		-- INSERT trigger for geom
		CREATE TRIGGER tr_usgs_wl_data_inserted_geom
			AFTER INSERT ON usgs_wl_data
			FOR EACH ROW
			EXECUTE PROCEDURE fn_usgs_wl_data_build_geom();
		
		-- UPDATE trigger for geom
		CREATE TRIGGER tr_usgs_wl_data_updated_coords
			AFTER UPDATE OF
			lat,
			lon
			ON usgs_wl_data
			FOR EACH ROW
			EXECUTE PROCEDURE fn_usgs_wl_data_build_geom();
EOSQL
done