from integrations.SlackIntegration import slackIntegration
import subprocess
import logging

def shell(cmd,ignore_slack=False):
    logger = logging.getLogger('reliability')
    rc = 0
    result = ""
    logger.info("=>" + cmd)
    try:
        result = subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True)
    except subprocess.CalledProcessError as cpe:
        rc = cpe.returncode
        result = cpe.output
        result_decode = result.decode("utf-8")
        # send slack message if oc command failed
        if not ignore_slack:
            slackIntegration.post_message_in_slack(f":boom: cmd: {cmd}  failed. Result: {result_decode}")

    string_result = result.decode("utf-8")
    logger.info(str(rc) + ": " + string_result)
    return string_result, rc

def oc(cmd, config="",ignore_slack=False):
    rc = 0
    result = ""
    if config:
        cmd = "oc --kubeconfig " + config + ' ' + cmd
    else:
        cmd = "oc " + cmd
    result,rc = shell(cmd,ignore_slack=ignore_slack)
    return result,rc

def kubectl(cmd, config=""):
    rc = 0
    result = ""
    if config:
        cmd = "kubectl --kubeconfig " + config + ' ' + cmd
    else:
        cmd = "kubectl " + cmd
    result,rc = shell(cmd)
    return result,rc

if __name__ == "__main__":
    (result, rc) = oc("get projects")
    print(rc)
