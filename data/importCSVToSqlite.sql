--
-- cat gtfsbrisbane/data/importCSVToSqlite.sql | sqlite3 -interactive -csv gtfs.sqlite
--
.mode csv

BEGIN TRANSACTION;

DROP TABLE IF EXISTS trip;
DROP TABLE IF EXISTS stop_time;
DROP TABLE IF EXISTS calendar;


.import trips.txt temp

CREATE TABLE "trip"(
"id" INTEGER PRIMARY KEY AUTOINCREMENT,
"trip_id" VARCHAR NOT NULL,
"route_id" VARCHAR NOT NULL,
"service_id" VARCHAR NOT NULL,
"headsign" VARCHAR NULL,
"short_name" VARCHAR NULL,
"direction_id" BOOLEAN NULL,
"block_id" VARCHAR NULL,
"shape_id" VARCHAR NULL,
"wheelchair_accessible" INTEGER NULL,
"bikes_allowed" INTEGER NULL
);
insert into trip (trip_id, route_id, service_id, headsign, short_name, direction_id, block_id, shape_id, wheelchair_accessible, bikes_allowed)
select trip_id, route_id, service_id, trip_headsign, NULL, direction_id, block_id, shape_id, NULL, NULL
from temp;

-- stops
--
DROP TABLE temp;
.import stops.txt temp

CREATE TABLE "stop"(
"id" INTEGER PRIMARY KEY AUTOINCREMENT,
"stop_id" VARCHAR NOT NULL,
"code" VARCHAR NULL,
"name" VARCHAR NOT NULL,
"desc" VARCHAR NULL,
"lat" REAL NOT NULL,
"lon" REAL NOT NULL,
"zone_id" VARCHAR NULL,
"url" VARCHAR NULL,
"location_type" INTEGER NULL,
"parent_station" VARCHAR NULL);

INSERT INTO stop (stop_id, code, name, desc, lat, lon, zone_id, url, location_type, parent_station)
select stop_id, stop_code, stop_name, stop_desc, stop_lat, stop_lon, zone_id, stop_url, location_type, parent_station
from temp;

-- stop_times
--
DROP TABLE temp;
.import stop_times.txt temp

CREATE TABLE "stop_time"(
"id" INTEGER PRIMARY KEY AUTOINCREMENT,
"trip_id" INTEGER NOT NULL REFERENCES "trip",
"trip" VARCHAR NOT NULL,
"arrival_time" TIME NOT NULL,
"departure_time" TIME NOT NULL,
"stop" VARCHAR NOT NULL,
"stop_id" INTEGER NOT NULL REFERENCES "stop",
"stop_sequence" VARCHAR NOT NULL,
"pickup_type" INTEGER NULL,
"drop_off_type" INTEGER NULL
);

-- XXX the time function here obviously can't convert 25:0X:XX entries in the
-- CSV ... not sure what I do about them... perhaps skip them as invalid for now?
--
insert into stop_time (trip_id, trip, arrival_time, departure_time, stop, stop_id, stop_sequence, pickup_type, drop_off_type)
select trip.id, temp.trip_id, time(temp.arrival_time), time(departure_time), temp.stop_id, stop.id, stop_sequence, pickup_type, drop_off_type
from temp, trip, stop
where temp.trip_id = trip.trip_id and temp.stop_id = stop.stop_id;

-- calendar
--
.import calendar.txt calendar

CREATE INDEX stop_seq_index ON stop_time (trip_id, stop_sequence);

DROP TABLE IF EXISTS temp;
COMMIT;
