-- Adjust to return actual geometry
CREATE OR REPLACE FUNCTION test_plr(query text)
RETURNS setof text AS $$

library(gstat)
library(raster)
library(data.table)
library(sf)


points <- pg.spi.exec(query)

## random locations and values
x=points$x
y=points$y
z=points$z
# plot(x,y)

## put locations in a dataframe, then convert it to a SpatialPointsDataFrame
dframe=data.frame(x=x,y=y,z=z)
coordinates(dframe) = ~x+y

##calculate experimental variogram
vex = variogram(z ~ 1,data=dframe)

##define variogram model (spherical, range=1.75, etc.  initial estimates.)
vg_model <- vgm(psill = NA, "Sph", range = 1.75, nugget = 0
                ,anis = c(0, 0, 0, 1.0, 1e-5)
)

##fit variogram model (vg_model) to experimental variogram data (vex)
vg_model <- fit.variogram(vex, model=vg_model, fit.method=1,fit.ranges = F)

## define ouput raster (locations for prediction)
out_rast=raster(extent(dframe),ncols=100,nrows=100)


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

## contour output grid as sp SpatialLines object
pred_contours_SpatialLines = rasterToContour(pred_raster)

## turn sp object into sf for better compatibility, etc.
contours_sf = st_as_sf(pred_contours_SpatialLines)

## convert sf to data.table
contours_dt = as.data.table(contours_sf)


## return if you define as an R function
return(st_as_text(contours_dt))

$$ LANGUAGE plr;