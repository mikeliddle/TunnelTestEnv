# Unbound

## Editing DNS entries

All DNS entries are stored in the a-records file. You can copy this into the container, or find it in the volume path. e.g. `/var/lib/docker/volumes/unbound/_data/a-records`. After editing this file, you should restart the unbound container to make sure the new entries take effect.

## Logs

The unbound container we use expects logging to be turned off for privacy reasons. Becasue of that, logging isn't hooked up to docker's standard logging, instead, you'll need to use `docker exec` to view the logs inside the container at this path: `/opt/unbound/etc/unbound/unbound.log`

e.g. `docker exec -it unbound tail -f /opt/unbound/etc/unbound/unbound.log`