GTFS-Schedule
=============

Be on time for your next public transport service.

## Motivation

>> What time do I need to leave the office to minimize waiting time for
>> my train?

The command is intended to be invoked frequently in a status bar (such as
[xmobar](https://github.com/jaor/xmobar)) showing next departing services for
one particular stop.

The command shows remaining minutes in order to leave the current spot (e.g.
office) to minimize the waiting time at the bus or train stop.


## Installation

The tool currently only supports [SEQ
Translink](https://gtfsrt.api.translink.com.au) datasets. See [issue
12](https://github.com/romanofski/gtfsschedule/issues/12) for supporting
more.

### From source

Haskell provides a tool called
[stack](https://docs.haskellstack.org/en/stable/README/) which can be installed
on many systems.

Using `stack` you can compile and install:

    stack install

in your local folder (`~/.local`). Make sure it is in your `$PATH`.

### Packages

Experimental packages are available for Fedora 24 via
[copr](https://copr.fedorainfracloud.org/coprs/romanofski/gtfsschedule/).

## Using

### Preparing the data

Run the setup command like:

    gtfsschedule setup

The database is created by default in: `$HOME/.local/share/gtfs/`

### Invoking the command

Find out which stop code it is you need to monitor from your service provider.

As an example this is Brisbane's Roma St, platform 8 stop code:
[600029](https://jp.translink.com.au/plan-your-journey/stops/600029).

Once you have your stop code, invoke the command to show next departing services:

    # Transport leaves in 11 minutes
    gtfsschedule monitor 600248 --walktime 0
    Desitnation 11 min (13:17:00)

The example invokes the command with an explicit `--walktime` option. The option
is used to indicate how long it takes to get to the stop. For example:

    # Transport leaves in 11 minutes, factor in a walk time to the stop/station of 7 minutes
    gtfsschedule monitor 600248 --walktime 7

    # Factor in realtime updates
    gtfsschedule monitor 600248 --walktime 7 -r

### Schedule change indicators

When you run the program with realtime updates, the following changes are indicated as follows:

    # Delayed service
    !GTPB Destination 11 min (13:17:06) (66s)  <-- delay
                              ^ departure time including delay

    # Canceled service
    GTPB Destination 11 min (13:17:00 !CANC!)


### Updating the database

The command checks if the dataset can be updated in which it prints a
"New dataset available" to stderr. Simply run:

    gtfsschedule setup

to update download a new dataset and update your database.

### Config examples for status monitors

Xmobar:

    Run Com "gtfsschedule" ["monitor", "600248", "-r", "--walktime", "7"] "gtfs" 600

Poor mans statusbar with `watch`. Use a terminal window and:

    watch -n 60 "gtfsschedule monitor 600248 --walktime 7"
