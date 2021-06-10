import subprocess
import logging

def shell(cmd):
    logger = logging.getLogger('reliability')
    rc = 0
    result = ""
    logger.info("=>" + cmd)
    try:
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as cpe:
        rc = cpe.returncode
        result = cpe.output

    string_result = result.decode("utf-8")
    logger.info(str(rc) + ": " + string_result)
    return string_result, rc

def oc(cmd, config=""):
    rc = 0
    result = ""
    if config:
        cmd = "oc --kubeconfig " + config + ' ' + cmd
    else:
        cmd = "oc " + cmd
    result,rc = shell(cmd)
    return result,rc



if __name__ == "__main__":
    (result, rc) = oc("get projects")
    print(rc)
