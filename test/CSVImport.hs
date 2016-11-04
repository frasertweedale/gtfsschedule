{-# OPTIONS_GHC -fno-warn-type-defaults #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module CSVImport (importTests) where

import qualified CSV.Import as CSV
import qualified Database as DB
import Schedule (getSchedule, TimeSpec(..), ScheduleItem(..), ScheduleState(..))

import Data.Functor ((<$>))
import Data.Time.LocalTime (TimeOfDay(..))
import Data.Time.Clock (getCurrentTime, UTCTime(..))
import Data.Time.Clock.POSIX (getPOSIXTime)
import Test.Tasty.HUnit (testCase, (@?=))
import Data.Time.Calendar (fromGregorian)
import Test.Tasty (TestTree, testGroup)

import Control.Concurrent (forkIO, takeMVar, putMVar, newEmptyMVar, killThread)
import Data.Conduit.Network (runTCPServer, serverSettings, ServerSettings, AppData, appSink)
import Data.Conduit (($$), yield)
import Data.Streaming.Network (bindPortTCP, setAfterBind)
import Network.Socket (sClose)
import qualified Data.IORef as I
import Control.Exception.Lifted (IOException, try, onException, bracket)
import System.IO.Unsafe (unsafePerformIO)
import System.Directory (getTemporaryDirectory, doesFileExist, removeFile)
import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as C8 (pack)

import System.IO.Temp (withSystemTempFile)
import qualified Data.Text as T


importTests ::
  TestTree
importTests = testGroup "import tests"
            [ testImportWithExistingDBFile
            , testImportWithoutExistingDBFile
            ]

testImportWithExistingDBFile :: TestTree
testImportWithExistingDBFile =
    testCase "imports all successfully" $
    withConcurrentTCPServer withHTTPAppData $
    \port ->
         do withSystemTempFile
                "ImportTest"
                (\tmpfile _ ->
                      do let url =
                                 concat ["http://", serverHost, ":", show port]
                         CSV.createNewDatabase url tmpfile
                         schedule <-
                             getSchedule
                                 tmpfile
                                 "600029"
                                 (TimeSpec
                                      (TimeOfDay 8 5 0)
                                      (fromGregorian 2015 1 28))
                         schedule @?=
                             [ ScheduleItem
                               { tripId = "QF0815-00"
                               , stopId = "600029"
                               , serviceName = "66 not relevant"
                               , scheduledDepartureTime = (TimeOfDay 8 5 0)
                               , departureDelay = 0
                               , departureTime = (TimeOfDay 8 5 0)
                               , scheduleType = SCHEDULED
                               }
                             , ScheduleItem
                               { tripId = "QF0815-00"
                               , stopId = "600029"
                               , serviceName = "66 not relevant"
                               , scheduledDepartureTime = (TimeOfDay 8 21 33)
                               , departureDelay = 0
                               , departureTime = (TimeOfDay 8 21 33)
                               , scheduleType = SCHEDULED
                               }])


testImportWithoutExistingDBFile :: TestTree
testImportWithoutExistingDBFile =
    testCase "imports by creating DB file" $
    withConcurrentTCPServer withHTTPAppData $
    \port ->
         do newdbfile <- generateTestUserDBFilePath
            onException (runImport port newdbfile) (cleanUpIfExist newdbfile)
            now <- getCurrentTime
            day <- DB.getLastUpdatedDatabase (T.pack newdbfile)
            day @?= utctDay now
  where
    runImport p userdbfile = do
        let url = concat ["http://", serverHost, ":", show p]
        CSV.createNewDatabase url userdbfile


generateTestUserDBFilePath :: IO FilePath
generateTestUserDBFilePath = do
  tmpdir <- getTemporaryDirectory
  dir <- generateName
  dbfile <- generateName
  let dirtree = concatMap (\x -> concat ["/", x]) [dir, dbfile]
  let newdbfile = tmpdir ++ dirtree
  return newdbfile

generateName :: IO String
generateName = do
  time <- round <$> getPOSIXTime
  return $ template ++ (show time)
    where template = "importest"

cleanUpIfExist :: FilePath -> IO ()
cleanUpIfExist fp = do
    fpExists <- doesFileExist fp
    if fpExists
        then removeFile fp
        else return ()

serverHost :: String
serverHost = "127.0.0.1"

nextPort :: I.IORef Int
nextPort = unsafePerformIO $ I.newIORef 1542
{-# NOINLINE nextPort #-}

getPort :: IO Int
getPort = do
    port <-
        I.atomicModifyIORef nextPort $
        \p ->
             (p + 1, p + 1)
    esocket <- try $ bindPortTCP port "*4"
    case esocket of
        Left (_ :: IOException) -> getPort
        Right socket -> do
            sClose socket
            return port

--
-- taken from https://github.com/snoyberg/http-client/blob/master/http-conduit/test/main.hs (withCApp)
--
withConcurrentTCPServer :: (AppData -> IO ()) -> (Int -> IO ()) -> IO ()
withConcurrentTCPServer app f = do
    port <- getPort
    baton <- newEmptyMVar
    let start = do
          putMVar baton ()
        settings :: ServerSettings
        settings = setAfterBind (const start) (serverSettings port "127.0.0.1")
    bracket
        (forkIO $ runTCPServer settings app `onException` start)
        killThread
        (const $ takeMVar baton >> f port)

withHTTPAppData :: AppData -> IO ()
withHTTPAppData appData = src $$ appSink appData
  where
    src = do
      yield "HTTP/1.1 200 OK\r\nContent-Type: application/x-zip-compressed\r\n"
      contents <- liftIO $ BS.readFile $ concat ["test", "/", "data", "/", "regular.zip"]
      let clength = BS.concat ["Content-Length: ", (C8.pack $ show $ BS.length contents), "\r\n"]
      yield $ BS.concat [clength, "\r\n", contents]
