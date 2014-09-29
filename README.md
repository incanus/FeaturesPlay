FeaturesPlay
============

Prototyping of projection conversion & spatial indexing routines. 

Rough work in progress, but just to cover the bases, some of the formulas are borrowed from [Leaflet](http://leafletjs.com). 

 * [x] Figure out how `MKMapPoint` is setup
 * [x] projected meters/map point/coordinate translations
 * [x] scale/zoom translations
 * [x] pixel width for zoom
 * [x] meters/pixel at given latitude & zoom
 * [x] Spherical Mercator
 * ~~[x] Mercator (ellipsoid)~~
 * [x] `CGPoint`/coordinate translations
 * [x] distance formulas
     - [x] Spherical Cosines
     - [x] Haversine
     - [x] Apple/Core Location passthrough
 * [ ] nearest neighbor
     - [x] Apple/Core Location passthrough
     - [ ] S2
     - [ ] R-Tree
     - [ ] Quad tree
     