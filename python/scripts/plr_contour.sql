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

## define ouput raster (locations for prediction)
out_rast=raster(extent(dframe),ncols=250,nrows=150)


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
return(contours_dt[,.(depth_towl_ft=z,geom=geometry)])

$function$;