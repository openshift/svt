import logging
from apscheduler.schedulers.background import BackgroundScheduler

class ScheduledTasks:
    def __init__(self):
        self.logger = logging.getLogger('reliability')
         # config scheduler
        executors = {
            'default': {'type': 'threadpool', 'max_workers': 60},
        }
        job_defaults = {
            'coalesce': False,
            'max_instances': 1
        }
        # init scheduler to be run in background
        self.scheduler = BackgroundScheduler(executors=executors, job_defaults=job_defaults)

    def start(self):
        # start background scheduler
        self.scheduler.start()

scheduledTasks = ScheduledTasks()
