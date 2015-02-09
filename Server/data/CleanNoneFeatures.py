layer = qgis.utils.iface.activeLayer()
iter = layer.getFeatures()
caps = layer.dataProvider().capabilities()

for feature in iter:
    # retrieve every feature with its geometry and attributes
    # fetch geometry
    geom = feature.geometry()
    # print "Feature ID %d: " % feature.id()
    
    if not geom is None:    
      if geom.wkbType() == QGis.WKBPoint25D:
        print "found point25d"
        print feature.attributes()
        print str(geom.asPoint())
    else: 
        print "nonetype"
        print str(feature)
        print feature.id()
        
        if caps & QgsVectorDataProvider.DeleteFeatures:
           print "can delete" 
           res = layer.dataProvider().deleteFeatures([feature.id()])
        
