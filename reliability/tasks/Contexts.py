from tasks.utils.oc import oc
from tasks.Session import Session
import logging
import os
import shutil
from concurrent.futures import ThreadPoolExecutor
from time import perf_counter

class Contexts:
    def __init__(self):
        self.kubeconfigs = {}
        self.logger = logging.getLogger('reliability')
        self.cwd = os.getcwd()

    # Create kubeconfig file and add context by login for each user
    def create_kubeconfigs(self, kubeconfig, users):
        self.logger.info('Creating kubeconfig files for users...')
        # clear kubeconfigs folder if already exist and create
        if os.path.exists(self.cwd + '/kubeconfigs'):
            shutil.rmtree(self.cwd + '/kubeconfigs')
        os.mkdir(self.cwd + '/kubeconfigs')

        login_args = []
        # make a copy of kubeconfig file for each user
        for name in users:
            kubeconfig_path = self.cwd + '/kubeconfigs/kubeconfig_' + name
            if os.path.isfile(kubeconfig_path):
                os.remove(kubeconfig_path)
            os.system('cp ' + kubeconfig + ' ' +  kubeconfig_path)
            self.kubeconfigs[name] = kubeconfig_path
            # prepare parameters list - username, password and kubeconfig - for Session.login
            login_args.append((users[name].name, users[name].password, kubeconfig_path))
        self.logger.info('Creating kubeconfig files for users is done.')

        # create context in each kubeconfig files by logging in with each user
        # run in parallel
        self.logger.info('Creating context for users...')
        #start = perf_counter()
        workers = 51
        # if max_workers=None, default is 5 * cpu cores
        with ThreadPoolExecutor(max_workers=workers) as executor:
            results = executor.map(lambda t: Session().login(*t), login_args)
            for result in results:
                self.logger.info(result)
        #end = perf_counter()
        #print('perf of {} workers is: {} second'.format(workers, end - start))
        self.logger.info('Creating context for users is done.')

    def init(self):
        pass

all_contexts = Contexts()

if __name__ == '__main__':
    class TestUser:
        def __init__(self):
            self.name = 'kubeadmin'
            self.password = '<password>'
    user = TestUser()
    users = {'kubeadmin': user}
    all_contexts.create_kubeconfigs('~/Downloads/kubeconfig', users)
    with open(os.getcwd() + '/kubeconfigs/kubeconfig_kubeadmin') as f:
        print(f.read())
