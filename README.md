# basemap

The background layer for the railway history map.

## Contents

* `install.sh`: run this once as root on a Debian buster system to install
  all the things we need, create a dedicated `basemap` user and the
  necessary PostgreSQL databases,

* `import.sh`: run this to download, filter, and import Openstreetmap
  data,

* `basemap/`: holds all configuration and style information. This will be
  copied to `/var/lib/basemap` by the install script and used during
  rendering,

* `basemap/mapserv.py`: a Python WSGI script rendering tiles from the
  database using Mapnik,

* `basemap/basemap.xml`: the XML configuration for Mapnik.
