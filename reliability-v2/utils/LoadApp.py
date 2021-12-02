from integrations.SlackIntegration import slackIntegration
import logging
from aiohttp import ClientSession
import asyncio
from time import perf_counter


class LoadApp():
    def __init__(self):
        self.logger = logging.getLogger('reliability')
        self.app_visit_succeeded = 0
        self.app_visit_failed = 0
        self.tasks = []

    async def get(self, url):
        try:
            # To simulate differnt users accessing same app, do not reuse session
            async with ClientSession() as session:
                async with session.get(url) as response:
                    code = response.status
                    result = await response.text()
                    self.logger.info(f"{str(code)} : load: {url}")
                    #print (f"{str(code)} : load: {url}")
                    if code == 200:
                        self.app_visit_succeeded += 1
                        return 0
                    else:
                        self.app_visit_failed += 1
                        # send slack message if response code is not 200
                        slackIntegration.post_message_in_slack(f":boom: Access to {url} failed. Response code: {str(code)}")
                        return 1
        except Exception as e :
            self.logger.error(f"LoadApp get: {url} Exception {e}")
            return 1

    def set_tasks(self, urls, num):
        for url in urls:
            for i in range(num):
                task = asyncio.ensure_future(self.get(url))
                self.tasks.append(task)

loadApp = LoadApp()

if __name__ == "__main__":
    loadApp = LoadApp()
    urls = ["https://www.google.com",]
    concurrency = 10
    loadApp.set_tasks(urls, concurrency)
    loop = asyncio.get_event_loop()
    start = perf_counter()
    loop.run_until_complete(asyncio.wait(loadApp.tasks))
    end = perf_counter()
    print(f"Perf of {concurrency} visits is: {end - start} second.")
    