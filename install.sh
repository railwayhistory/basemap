#! /bin/sh
#
# Installs all necessary dependencies on a Debian buster system.
#
# This needs to be run only once. It must be executed as root and the current
# directory must be the checked out repository.


#--- Add the backports repository.
#
# We need it for some fast-moving projects.
#
apt-get install apt-transport-https
echo "deb https://deb.debian.org/debian buster-backports main" \
	> /etc/apt/sources.list.d/backports.list
apt-get update


#--- Install all the software
#
# We need PostgresSQL and PostGIS to store data, Mapnik for rendering the
# map tiles, Falcon and uWSGI for serving the tiles later. Osmium is used
# to pre-process OSM data and osm2pgsql loads it into the database. In
# addition, there are a few things that a basic Debian installation may not
# have.
apt-get install postgresql-11 postgis mapnik-utils python3-mapnik \
    python3-falcon uwsgi uwsgi-plugin-python3
apt-get install -t buster-backports osmium-tool osm2pgsql
apt-get install sudo unzip


#--- Create user basemap and /var/lib/basemap
#
# PostgreSQL uses system users for authentication. The rendering service
# will require access to the database, so it gets its own dedicated user.
# We will also use that user during the entire import process and place all
# supporting files into its home directory /var/lib/basemap. Those files all
# live in the basemap directory of the repository, so we can copy that.
adduser --system --home /var/lib/basemap --disabled-login basemap
cp -dR basemap/* /var/lib/basemap/


#--- Prepare the database
#
# We create a database user, a database, and enable PostGIS on it.
sudo -u postgres createuser basemap
sudo -u postgres createdb --encoding=UTF8 --owner basemap basemap
sudo -u postgres psql -d basemap \
	-c 'CREATE EXTENSION postgis; CREATE EXTENSION hstore;'

