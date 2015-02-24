from gtfsbrisbane.entry import Entry
import lxml


class DataProvider:

    def __init__(self, fp, xpath="//div[@id='timetable']/table/tbody/tr"):
        self._fp = fp
        self.xpath = xpath

    @property
    def contents(self):
        return self.parse(self._fp)

    def parse(self, fp):
        return ""

    def get_schedule(self, filter_by=None):
        """ Returns the next scheduled hits. By default all parsed hits.
        """
        result = []
        for row in self.contents.xpath(self.xpath):
            route, direction, scheduled = (
                [x.text_content().strip() for x in row.xpath('td')]
            )
            # We only need the time and not the rest of the information
            # in the scheduled table column
            scheduled = scheduled.split()[0]
            entry = Entry(route, direction, scheduled)
            # Return the whole schedule
            if filter_by is None:
                result.append(entry)
            # Return only what we need
            elif route in filter_by:
                result.append(entry)

        return result


class HtmlDataProvider(DataProvider):

    def parse(self, fp):
        return lxml.html.parse(fp)
