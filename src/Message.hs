{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE PatternGuards     #-}
-- | A real time update from the GTFS feed
module Message where

import Schedule (ScheduleItem(..), ScheduleType(..), secondsToDeparture)

import Com.Google.Transit.Realtime.TripUpdate.StopTimeEvent (StopTimeEvent(..), delay)
import Com.Google.Transit.Realtime.TripDescriptor (trip_id, TripDescriptor(..))
import qualified Com.Google.Transit.Realtime.TripDescriptor.ScheduleRelationship as TripSR
import qualified Com.Google.Transit.Realtime.TripUpdate.StopTimeUpdate.ScheduleRelationship as StopTUSR
import qualified Com.Google.Transit.Realtime.TripUpdate.StopTimeUpdate as STU
import qualified Com.Google.Transit.Realtime.FeedMessage as FM
import qualified Com.Google.Transit.Realtime.TripUpdate as TU
import qualified Com.Google.Transit.Realtime.FeedEntity as FE

import Text.ProtocolBuffers (utf8)
import Text.ProtocolBuffers.Basic (Utf8)
import qualified Text.ProtocolBuffers.Header as P'
import qualified Data.ByteString.Lazy.UTF8 as U (toString)
import Data.Time.LocalTime (timeToTimeOfDay, TimeOfDay)
import Data.Time.Clock (secondsToDiffTime)
import Data.Foldable (find)
import qualified Data.Map.Lazy as Map
import Control.Monad (mfilter)
import Control.Monad.State (State, execState, get, put)
import Debug.Trace (trace)


getFeedEntities ::
  FM.FeedMessage
  -> P'.Seq TU.TripUpdate
getFeedEntities fm = (`P'.getVal` FE.trip_update) <$> entity
  where entity = P'.getVal fm FM.entity

-- | filter out all relevant trips for the given schedule
--
-- relevant means it matches the trip_id and has a start time set.
--
filterTripUpdate ::
  [ScheduleItem]
  -> P'.Seq TU.TripUpdate
  -> P'.Seq TU.TripUpdate
filterTripUpdate xs = mfilter (\x -> getTripID x `elem` relevantTripIDs)
  where
    relevantTripIDs = tripId <$> xs

getTripID ::
  TU.TripUpdate
  -> String
getTripID x = utf8ToString tripID
  where
    descriptor = P'.getVal x TU.trip
    tripID = P'.getVal descriptor trip_id

-- | Updates schedule with trip updates given by feed
--
updateSchedule ::
  [ScheduleItem]
  -> FM.FeedMessage
  -> [ScheduleItem]
updateSchedule schedule fm = Map.elems $ execState (mapM updateForTrip tripUpdates) m
  where
    tripUpdates = filterTripUpdate schedule $ getFeedEntities fm
    m = Map.fromList $ toMap <$> schedule
    toMap x = (tripId x, x)

updateForTrip ::
  TU.TripUpdate
  -> State (Map.Map String ScheduleItem) ()
updateForTrip tu = do
  m <- get
  let (_, map') = Map.updateLookupWithKey (f tu) (getTripID tu) m
  put map'
  where
    f TU.TripUpdate { TU.trip = TripDescriptor { schedule_relationship = Just TripSR.CANCELED }} k item =
      Just ScheduleItem { tripId = k
                        , stopId = stopId item
                        , serviceName = serviceName item
                        , scheduledDepartureTime = scheduledDepartureTime item
                        , departureDelay = 0
                        , departureTime = departureTime item
                        , scheduleType = CANCELED
                        }
    f _ k item = do
      stu <- findStopTimeUpdate (stopId item) (getStopTimeUpdates tu)
      Just ScheduleItem { tripId = k
                        , stopId = stopId item
                        , serviceName = serviceName item
                        , scheduledDepartureTime = scheduledDepartureTime item
                        , departureDelay = getDepartureDelay stu
                        , departureTime = departureTimeWithDelay (scheduledDepartureTime item) (getDepartureDelay stu)
                        , scheduleType = scheduleTypeForStop stu
                        }

-- | helper to set the appropriate schedule type if the service will skip this stop
--
scheduleTypeForStop ::
  STU.StopTimeUpdate
  -> ScheduleType
scheduleTypeForStop STU.StopTimeUpdate { STU.schedule_relationship = Just StopTUSR.SKIPPED } = CANCELED
scheduleTypeForStop _ = SCHEDULED


departureTimeWithDelay ::
  TimeOfDay
  -> Integer
  -> TimeOfDay
departureTimeWithDelay depTime d = timeToTimeOfDay $ secondsToDeparture depTime (secondsToDiffTime d)

getStopTimeUpdates ::
  TU.TripUpdate
  -> P'.Seq STU.StopTimeUpdate
getStopTimeUpdates msg = P'.getVal msg TU.stop_time_update

findStopTimeUpdate ::
  String
  -> P'.Seq STU.StopTimeUpdate
  -> Maybe STU.StopTimeUpdate
findStopTimeUpdate stopID = find (\x -> stopTimeUpdateStopID x == stopID)

stopTimeUpdateStopID ::
  STU.StopTimeUpdate
  -> String
stopTimeUpdateStopID msg = utf8ToString $ P'.getVal msg STU.stop_id

getDepartureDelay ::
  STU.StopTimeUpdate
  -> Integer
getDepartureDelay update = fromIntegral $ P'.getVal d delay
  where d = P'.getVal update STU.departure

-- private helpers
--
utf8ToString ::
  Utf8
  -> String
utf8ToString = U.toString . utf8
