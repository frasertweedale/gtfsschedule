from gtfsbrisbane import __description__
from gtfsbrisbane import __version__
from gtfsbrisbane.config import APIURL
import argparse
import gtfsbrisbane.queue


def configure_commandline():
    parser = argparse.ArgumentParser(
        description='{name} {version} -- {description}'.format(
            name=__name__, version=__version__,
            description=__description__))
    parser.add_argument(
        "routes",
        help=("A list of routes which which should be listed."
              " e.g. 'CAIP BRSP BRIP'"),
        type=str
    )
    parser.add_argument(
        "--delay",
        help=("Delay the timing so you arrive on time at the station."
              " e.g. --delay=5 to see trains leaving +5min ahead."),
        type=int,
        default=0
    )
    parser.add_argument(
        "--stop",
        help=("A stop id to use for schedule querying."
              " Defaults to Roma St, stop number: 600029"),
        type=str,
        default=600029
    )
    parser.add_argument(
        "--version",
        action="version",
        version="{name} {version}".format(
            name=__name__, version=__version__)
    )
    parser.add_argument(
        "-r",
        "--reset",
        dest='reset',
        help=("Load schedule from the online source."),
        action="store_true")

    return parser.parse_args()


def showtrains():
    arguments = configure_commandline()
    routes = arguments.routes.split()

    queue = gtfsbrisbane.queue.Queue(
        APIURL.format(stopid=arguments.stop), routes)
    trains = queue.get_next_trains(fetch=arguments.reset,
                                   delay=arguments.delay)
    if not trains:
        print("No train data available.")
    else:
        data = ['{x.direction} - {x.departs}'.format(x=x) for x in trains[:2]]
        print(' / '.join(data))
