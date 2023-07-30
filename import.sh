#! /bin/bash
#
# Imports Openstreetmap data into the database.
#
# This must be run as your dedicated database user. E.g.:
#
#     sudo -u basemap ./import.sh
#
# If the auxiliary files used aren’t in a directory basemap below where this
# script lives, specify their directory as the first argument.
#
# This script may not actually work on BSD systems.


#------------- Housekeeping --------------------------------------------------
#
# Before we do actual work, some housekeeping. We need to find our own
# auxiliary files and create a temporary directory for the files we download.

# Find out where our files live
#
# This is either the first argument or, if that is missing, basemap under the
# script’s directory.
# Error out early if that directory doesn’t exist.
#
# The directory name will end up in $BASEMAP.
#
if [ ! -z "$1" ]; then
    BASEMAP="$1"
else
    BASEMAP="$(dirname $0)/basemap"
fi
if [ ! -d "$BASEMAP" ]; then
    echo "Basemap directory $BASEMAP not found."
    exit 1
fi

# Prepare a spool directory.
#
# The spool directory hosts all the input files. It can either be given via
# the second argument or, if that is missing, a temporary directory is
# created. In this case we also install a trap so that this directory gets
# deleted whenever the script bails out early.
#
# The directory will be $SPOOLDIR.
if [ ! -z "$2" ]; then
    SPOOLDIR="$2"
    if [ ! -d "$SPOOLDIR" ]; then
        mkdir "$SPOOLDIR"
    fi
else
    SPOOLDIR=`mktemp -d`

    delete_spool() {
        rm -rf "$SPOOLDIR"
    }

    trap delete_spool EXIT
fi


#------------- Import Basic OSM Data -----------------------------------------
#
# In this step, we fetch a database excerpt from Openstreetmap, called a
# ‘planet,’ filter out the data we actually want to keep it small, and import
# that into our database so we can use it for rendering later.
#
# A full planet currently is around 50GB. Since we only need coverage for part
# of the world, we can limit the size by downloading an excerpt instead.
# Geofabrik kindly provides an excellent selection of such excerpts. See
# http://download.geofabrik.de/ for those. A full planet should be downloaded
# via one of the mirrors. See https://wiki.openstreetmap.org/wiki/Planet.osm
#
PLANET_URI=https://download.geofabrik.de/europe/germany-latest.osm.pbf

# For testing purposes, we skip this whole step if $BASEMAP/no-planet exists.
#
if [ ! -f "$BASEMAP/no-planet" ]; then

    #--- Fetch and pre-process the planet.
    #
    # We place it into a file $PLANET_SOURCE. If that already exist, we reuse
    # it.
    #
    PLANET_SOURCE=$SPOOLDIR/`basename $PLANET_URI`
    if [ ! -f "$PLANET_SOURCE" ]; then
        wget -O "$PLANET_SOURCE" "$PLANET_URI"
    fi

    # Now we use Osmium to filter out unwanted data from the source planet and
    # turn that into $PLANET_TARGET. Osmium can use an expression file for the
    # tag filter. We use that and read expressions from $BASEMAP/tags-filter.
    #
    PLANET_TARGET="$SPOOLDIR/planet-target.pbf"
    osmium tags-filter -e "$BASEMAP/tags-filter" "$PLANET_SOURCE" \
        --overwrite -o "$PLANET_TARGET"


    #--- Import the planet into the database.
    #
    # The -C option should be around 1.3 times the size of $PLANET_TARGET in
    # MBytes. (So the 3000 here is for a 2GB file.)
    osm2pgsql --slim --database -C 3000 basemap "$PLANET_TARGET"

fi


#------------- Import Coastlines Data ----------------------------------------
#
# Coastlines are notoriously tricky and are therefore excluded from the data
# imported above. Instead, there is a tool called OSMCoastline that
# preprocesses # the data and produces them as shapefiles. The resulting files
# are provided # at https://osmdata.openstreetmap.de/data/coast.html. We
# simply download the data sets we need and import them into the database,
# each in their own table.
#
# We need three sets: Water polygons in regular and reduced resolution and
# the coastlines themselves. These are available at:
#
#     https://osmdata.openstreetmap.de/download/$SHAPE-split-3857.zip
#
# where the shapes we are interested in are water-polygons,
# simplified-water-polygons, and coastlines.
#
# We place their contents into database tables with the same name but
# underscores instead of dashes.

# Same deal: Skip if $BASEMAP/no-shapes exists
#
if [ ! -f "$BASEMAP/no-shapes" ]; then

    # Fetch the files and unzip them.
    #
    # If the directory for the unzipped content is already there, skip.
    SHAPEFILE="water-polygons simplified-water-polygons coastlines"
    for SHAPE in $SHAPEFILE; do
        if [ ! -d "$SPOOLDIR/$SHAPE-split-3857" ]; then
            wget -O "$SPOOLDIR/$SHAPE.zip" \
                https://osmdata.openstreetmap.de/download/$SHAPE-split-3857.zip
            unzip -d "$SPOOLDIR" "$SPOOLDIR/$SHAPE.zip"
        fi
    done

    # Import into the database.
    #
    # PostGIS comes with a tool, shp2pgsql, for this purpose.
    #
    import_shape() {
        # -d drops the table before creating
        # -s 3857 makes us use Mercator projection
        # -I makes indexes.
        shp2pgsql -d -s 3857 -I "$SPOOLDIR/$1-split-3857/$2" $3 \
            | psql -d basemap
    }
    import_shape water-polygons water_polygons water_polygons
    import_shape simplified-water-polygons \
        simplified_water_polygons simplified_water_polygons
    import_shape coastlines lines coastlines
fi

