import tempfile, shutil


class FakeClient:
    def __init__(self):
        pass

    def login(self, user, passwd, master):
        return True

    def oc_command(self, args, globalvars):
        tmpfile = tempfile.NamedTemporaryFile()
        # see https://github.com/openshift/origin/issues/7063 for details why this is done.
        shutil.copyfile(globalvars["kubeconfig"], tmpfile.name)
        ret = True
        if globalvars["debugoption"]:
            print args
        tmpfile.close()
        return ret