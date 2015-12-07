{-# LANGUAGE DeriveGeneric #-}
-- | the GTFS schedule
module Schedule
    (printSchedule
    , filterSchedule
    , parseCSV
    , filterRecords
    , StopTime(..)
    , nowAsTimeOfDay
    , isIrrelevantRecord
    , isInvalidStop
    , isInvalidWeekday
    , isInvalidDepartureTime
    , minutesToDeparture
    ) where

import Data.Csv ( FromNamedRecord(..)
                , FromField(..)
                , ToField(..)
                , ToNamedRecord(..)
                , DefaultOrdered
                , encodeDefaultOrderedByName)
import Data.Csv.Streaming
import Data.Time.LocalTime ( TimeOfDay
                           , TimeZone
                           , utcToLocalTimeOfDay
                           , timeToTimeOfDay
                           , timeOfDayToTime)
import Data.Time.Format (parseTimeM, defaultTimeLocale, formatTime)
import Data.Time (getCurrentTime, getCurrentTimeZone)
import Data.Time.Clock ( UTCTime(..)
                       , DiffTime)
import Control.Applicative (empty)
import GHC.Generics
import Data.List (sort, isInfixOf)
import qualified Data.ByteString.Char8 as C
import qualified Data.ByteString.Lazy as B
import qualified Data.Foldable as F


data StopTime = StopTime { trip_id :: !String
                         , arrival_time :: !TimeOfDay
                         , departure_time :: !TimeOfDay
                         , stop_id :: !String
                         , stop_sequence :: !Int
                         , pickup_type :: !Int
                         , drop_off_type :: !Int
                         }
              deriving (Eq, Generic, Show)

instance Ord StopTime where
  compare x y = compare (departure_time x) (departure_time y)

instance FromNamedRecord StopTime
instance ToNamedRecord StopTime
instance DefaultOrdered StopTime

instance FromField TimeOfDay where
  parseField s = case parseTimeM True defaultTimeLocale "%T" (C.unpack s) of
    Just t -> pure t
    Nothing -> empty

instance ToField TimeOfDay where
  toField t = C.pack $ formatTime defaultTimeLocale "%T" t

-- | parses CSV file and returns either a parser error or a list of stop times
--
parseCSV ::
  B.ByteString
  -> IO (Either String (Records StopTime))
parseCSV contents =
  case decodeByName contents of
    Left errmsg -> return $ Left errmsg
    Right (_, r) -> return $ Right r

filterRecords ::
  (StopTime -> Bool)
  -> Records StopTime
  -> [StopTime]
filterRecords p = F.foldr (\x a -> if p x then x : a else a) []

nowAsTimeOfDay ::
  UTCTime
  -> TimeZone
  -> TimeOfDay
nowAsTimeOfDay t tz = snd $ utcToLocalTimeOfDay tz (toTimeOfDay t)
    where toTimeOfDay (UTCTime _ utcDayTime) = timeToTimeOfDay utcDayTime

-- | predicate to filter out unneeded records
-- TODO: yikes how to do this better?
--
isIrrelevantRecord ::
  String
  -> String
  -> TimeOfDay
  -> StopTime
  -> Bool
isIrrelevantRecord stopID weekday now x = isInvalidStop stopID x
                                          && isInvalidDepartureTime now x
                                          && isInvalidWeekday weekday x

isInvalidStop ::
  String
  -> StopTime
  -> Bool
isInvalidStop stopID x = stop_id x == stopID

isInvalidWeekday ::
  String
  -> StopTime
  -> Bool
isInvalidWeekday weekday x = weekday `isInfixOf` trip_id x

isInvalidDepartureTime ::
  TimeOfDay
  -> StopTime
  -> Bool
isInvalidDepartureTime now x = departure_time x >= now

-- | shows meaningful information for leaving trains
--
printStopTimesAsSchedule ::
  TimeOfDay
  -> [StopTime]
  -> String
printStopTimesAsSchedule now (StopTime { departure_time = depTime } : xs) =
  show (minutesToDeparture now depTime) ++ " (" ++ show depTime ++ ") " ++ printStopTimesAsSchedule now xs
printStopTimesAsSchedule _ [] = []

minutesToDeparture ::
  TimeOfDay
  -> TimeOfDay
  -> Integer
minutesToDeparture now dep_time = round $ toRational (timeOfDayToTime dep_time - timeOfDayToTime now) / 60

-- | prints list of StopTimes as schedule
--
printSchedule ::
  String
  -> B.ByteString
  -> IO ()
printSchedule sId c = do
  parsed <- parseCSV c
  case parsed of
    Left err -> print err
    Right r -> do
      t <- getCurrentTime
      tz <- getCurrentTimeZone
      let nowToD = nowAsTimeOfDay t tz
      let weekday = formatTime defaultTimeLocale "%A" t
      let xs = sort $ filterRecords (isIrrelevantRecord sId weekday nowToD) r
      print $ printStopTimesAsSchedule nowToD $ take 2 xs

-- | parse and write only stop id dependend records to CSV
--
filterSchedule ::
  String
  -> B.ByteString
  -> IO ()
filterSchedule sId c = do
  parsed <- parseCSV c
  case parsed of
    Left err -> print err
    Right r -> do
      let xs = sort $ filterRecords (isInvalidStop sId) r
      B.putStr $ encodeDefaultOrderedByName xs
