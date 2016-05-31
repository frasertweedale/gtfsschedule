module Main where

import Schedule (printSchedule, getSchedule)
import Message (printUpdatedSchedule)

import Options.Applicative.Builder (long
                                   , help
                                   , (<>)
                                   , metavar
                                   , option
                                   , argument
                                   , str
                                   , fullDesc
                                   , progDesc
                                   , header
                                   , info
                                   , auto)
import Options.Applicative (optional)
import Options.Applicative.Types (Parser)
import Options.Applicative.Extra ( execParser
                                 , helper)
import Data.Maybe (fromMaybe)
import Network.HTTP.Conduit (simpleHttp)

import Text.ProtocolBuffers (messageGet)


type Station = String
type SQLiteDBPath = FilePath
type WalkTime = Integer

data Options = Options { stationID :: String
                       , sqliteDBFile :: FilePath
                       , walktime :: Maybe Integer
                       }

optionParser ::
  Parser Options
optionParser = Options
               <$> argument str
               ( metavar "filepath"
                 <> help "filepath to sqlite3 database populated with GTFS static data feed")
               <*> argument str
               ( metavar "station"
                 <> help "Station id to show the schedule for")
               <*> (optional $ option auto
               ( long "walktime"
                 <> help "Time to reach the stop. Will be added to the current time to allow arriving at the stop on time."))

delayFromMaybe ::
  Maybe Integer
  -> Integer
delayFromMaybe = fromMaybe 0

runSchedule :: Options -> IO ()
runSchedule (Options fp sID delay) = do
  schedule <- getSchedule fp sID $ delayFromMaybe delay
  bytes <- simpleHttp "http://gtfsrt.api.translink.com.au/Feed/SEQ"
  case messageGet bytes of
    Left err -> do
      print err
      printSchedule schedule
    Right (fm, _) -> printUpdatedSchedule fm schedule

main :: IO ()
main = execParser opts >>= runSchedule
  where opts = info (helper <*> optionParser)
               ( fullDesc
                 <> progDesc "Shows schedule of departing vehicles based on static GTFS data."
                 <> header "gtfs - a gtfs enabled transport schedule")
