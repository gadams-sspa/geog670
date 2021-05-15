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
			datetime timestamp NULL,
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
		
		-- Create plr_contour function
		CREATE OR REPLACE FUNCTION public.plr_contour(query text)
		RETURNS SETOF gw_contour
		LANGUAGE plr
		AS $function$

		library(gstat)
		library(raster)
		library(data.table)
		library(sf)


		points <- pg.spi.exec(query)

		x=points$x
		y=points$y
		z=points$z
		# plot(x,y)

		## put locations in a dataframe, then convert it to a SpatialPointsDataFrame
		dframe=data.frame(x=x,y=y,z=z)

		coordinates(dframe) = ~x+y

		##calculate experimental variogram
		vex = variogram(z ~ 1,data=dframe)

		## random locations and values
		vg_model <- vgm(psill = NA, "Sph", range = 5, nugget = 0
						,anis = c(0, 0, 0, 1.0, 1e-5)
		)

		##fit variogram model (vg_model) to experimental variogram data (vex)
		vg_model <- fit.variogram(vex, model=vg_model, fit.method=1,fit.ranges = F)

		## define ouput raster (locations for prediction) USING extent OF continuous US IN EPSG 4269
		out_rast=raster(extent(-125,25,-67,50),ncols=250,nrows=200)


		## append EVENT field to data.table of XY coords
		# outgrid=data.table(outgrid, NROW(outgrid))))

		## set up kriging model
		gmodel <- gstat(formula = z~1,
						data = dframe, model= vg_model)

		## convert output raster locations to spatial pixels data frame object
		out_SpatialPixels = as(out_rast,"SpatialPixels")

		## get predicted (kriged) values at grid locations
		pred_SpatialPixels = predict(gmodel,out_SpatialPixels)

		## convert SpatialPixelsDataFrame to raster object
		pred_raster = raster(pred_SpatialPixels)

		## contour intervals
		contour_levels=seq(from=range(pretty(dframe$z))[1],to=range(pretty(dframe$z))[2],by=20)

		## contour output grid as sp SpatialLines object
		pred_contours_SpatialLines = rasterToContour(pred_raster,levels=contour_levels)

		## turn sp object into sf for better compatibility, etc.
		contours_sf = st_as_sf(pred_contours_SpatialLines)

		## convert sf to data.table
		contours_dt = as.data.table(contours_sf)

		##convert geometry to WKT
		contours_dt[,geometry:=st_as_text(geometry)]

		## return if you define as an R function
		return(contours_dt[,.(depth_towl_ft=level,geom=geometry)])

		$function$;
EOSQL
done