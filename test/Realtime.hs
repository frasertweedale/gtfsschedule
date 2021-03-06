module Realtime (feedTests) where

import Message
import Schedule

import Data.Functor ((<$>))

import Test.Tasty (TestTree, TestName, testGroup)
import Test.Tasty.HUnit (testCase, (@?=))
import Data.Time.LocalTime (TimeOfDay(..))
import Text.ProtocolBuffers (messageGet)

import qualified Data.ByteString.Lazy as L


feedTests ::
  TestTree
feedTests = testGroup "realtime feed Tests"
            [ testDepartureWithDelay
            , testWithRealtimeFeed
            ]


makeFeedTest ::
  (Eq a, Show a)
  => (TestName, FeedMessage -> a, a)
  -> TestTree
makeFeedTest (name, prepare, expected) = testCase name $ do
  feed <- withFeed "test/data/feed.bin"
  let items = prepare feed
  items @?= expected

testWithRealtimeFeed ::
  TestTree
testWithRealtimeFeed = testGroup "with realtime feed" $ makeFeedTest <$>
  [ ("full updates", updateSchedule
      [ ScheduleItem { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
                     , stopId = "301350"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 10 30 00
                     , scheduleType = SCHEDULED
                     }
      , ScheduleItem { tripId = "7822824-BT 16_17-JUL_FUL-Sunday-02"
                     , stopId = "11168"
                     , serviceName = "S1"
                     , scheduledDepartureTime = TimeOfDay 8 00 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 8 00 00
                     , scheduleType = SCHEDULED
                     }
      ],
      [ ScheduleItem { tripId = "7822824-BT 16_17-JUL_FUL-Sunday-02"
                     , stopId = "11168"
                     , serviceName = "S1"
                     , scheduledDepartureTime = TimeOfDay 8 00 00
                     , departureDelay = 66
                     , departureTime = TimeOfDay 8 01 06
                     , scheduleType = SCHEDULED
                     }
      , ScheduleItem { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
                     , stopId = "301350"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 155
                     , departureTime = TimeOfDay 10 32 35
                     , scheduleType = SCHEDULED
                     }
      ]
    )
  , ("no updates", updateSchedule
      [ ScheduleItem { tripId = "has no realtime update"
                     , stopId = "232323"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 8 00 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 8 00 00
                     , scheduleType = SCHEDULED
                     }
        ],
     [ ScheduleItem { tripId = "has no realtime update"
                    , stopId = "232323"
                    , serviceName = "S2"
                    , scheduledDepartureTime = TimeOfDay 8 00 00
                    , departureDelay = 0
                    , departureTime = TimeOfDay 8 00 00
                    , scheduleType = SCHEDULED
                    }
     ]
    )
  , ("partial update", updateSchedule
      [ ScheduleItem { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
                     , stopId = "301350"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 10 30 00
                     , scheduleType = SCHEDULED
                     }
      , ScheduleItem { tripId = "no realtime update"
                     , stopId = "0815"
                     , serviceName = "S1"
                     , scheduledDepartureTime = TimeOfDay 8 00 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 8 00 00
                     , scheduleType = SCHEDULED
                     }
      ],
      [ ScheduleItem { tripId = "7935244-SBL 16_17-SBL_SUN-Sunday-01"
                     , stopId = "301350"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 155
                     , departureTime = TimeOfDay 10 32 35
                     , scheduleType = SCHEDULED
                     }
      , ScheduleItem { tripId = "no realtime update"
                     , stopId = "0815"
                     , serviceName = "S1"
                     , scheduledDepartureTime = TimeOfDay 8 00 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 8 00 00
                     , scheduleType = SCHEDULED
                     }
     ])
  , ("canceled service", updateSchedule
      [ ScheduleItem { tripId = "7634889-SUN 16_17-SUN_SUN-Sunday-01"
                     , stopId = "317579"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 10 30 00
                     , scheduleType = SCHEDULED
                     }
      ],
      [ ScheduleItem { tripId = "7634889-SUN 16_17-SUN_SUN-Sunday-01"
                     , stopId = "317579"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 10 30 00
                     , scheduleType = CANCELED
                     }
     ])
  , ("skipped stop", updateSchedule
      [ ScheduleItem { tripId = "8153081-QR 16_17-Jul_Sun-Sunday-00-1E41"
                     , stopId = "600202"
                     , serviceName = "S2"
                     , scheduledDepartureTime = TimeOfDay 10 30 00
                     , departureDelay = 0
                     , departureTime = TimeOfDay 10 30 00
                     , scheduleType = SCHEDULED
                     }
        ],
     [ ScheduleItem { tripId = "8153081-QR 16_17-Jul_Sun-Sunday-00-1E41"
                    , stopId = "600202"
                    , serviceName = "S2"
                    , scheduledDepartureTime = TimeOfDay 10 30 00
                    , departureDelay = 0
                    , departureTime = TimeOfDay 10 30 00
                    , scheduleType = CANCELED
                    }
     ])
  ]

testDepartureWithDelay ::
  TestTree
testDepartureWithDelay = testGroup "check departure with delay" $ makeTest <$>
  [ ("delayed", departureTimeWithDelay (TimeOfDay 7 0 0) 30, TimeOfDay 7 0 30)
  , ("ahead", departureTimeWithDelay (TimeOfDay 7 0 0) (-30), TimeOfDay 6 59 30)
  ]

withFeed ::
  FilePath
  -> IO FeedMessage
withFeed fp = do
  contents <- L.readFile fp
  case messageGet contents of
    Left err -> error err
    Right (fm, _) -> return fm

makeTest (name, input, expected) = testCase name $ input @?= expected
