# Get the SF Street Sweeping data

Provided as ESRI Shapefiles:

https://data.sfgov.org/City-Infrastructure/Street-Sweeper-Scheduled-Routes-Zipped-Shapefile-F/wwci-6uqu

Download and unzip those.

# Convert Shapefiles to WGS84 Projection

The SF shapefiles are in Northern California specific projection (2227). Lat/long coordinates are in WGS84 projection (4326)

Download the GDAL tools (http://trac.osgeo.org/gdal/wiki/DownloadingGdalBinaries) to get access to the ogr2ogr tool to directly convert.

Or use QGIS to load the shapevile as a vector, then export it out using the WGS84 projection (http://cl.ly/image/2R0c413R1r0k).

# Convert Shapefile to GeoJSON

ogr2ogr -f geoJSON sweeping.json sfsweeproutes_in_wgs84.shp

# Clean up the resulting GeoJSON

MongoImport doesn't like the ogr2ogr generated GeoJSON. Remove the first two lines:

```{
"type": "FeatureCollection",
```
and the last line:

```}```

and save that to `sweeping_clean.json`

# Import the data to Mongo

`mongoimport --db sfstreets --collection streets < sweeping_clean.json`

# Create a 2dsphere spatial index

Mongo needs an index to query on geospatial data. To create it from the `mongo` command line:

`db.streets.ensureIndex({"geometry":"2dsphere"})`

Where `streets` is your collection name and `geometry` is the object in your document that contains the GeoJSON location data.
