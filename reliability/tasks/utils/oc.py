import subprocess
import logging

def oc(cmd, config=""):
    logger = logging.getLogger('reliability')
    cmd = "oc " + cmd
    rc = 0
    result = ""
    logger.info("=>" + cmd)
    if config:
        cmd = "KUBECONFIG=" + config + " " + cmd
    try:
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as cpe:
        rc = cpe.returncode
        result = cpe.output
    
    string_result = result.decode("utf-8")
    logger.info(str(rc) + ": " + string_result)
    return string_result, rc



if __name__ == "__main__":
    (result, rc) = oc("get projects")
    print(rc)