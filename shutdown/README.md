OpenShift V4 Shutdown 
===========================

This uses python 3

Install Packages
```
pip install -r requirements.txt
```

### Config Explanation



```
shutdown:
  - downtime: 60 s (the amount of time for the cluster be shutdown
    shutdown_master_num: <num> or <all> (all is default) 
    shutdown_worker_num: <num> or <all> (all is default) 
    shutdown_infra_num:  <num> or <all> (all is default) 
    cloud_type: az or aws or gcp
    ssh_file: "" ( location of ssh file to use when shutting down nodes by not cloud provider) (will not be able to restart nodes with this method)
    kubeconfig_path: ~/.kube/config (location of kube configuration)
```
    
### Different Cloud Provider Set Up

#### AWS 

**NOTE**: For clusters with AWS make sure [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) is installed and properly [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) using an AWS account

#### GCP
**NOTE**: For clusters with GCP make sure [GCP CLI](https://cloud.google.com/sdk/docs/install#linux) is installed.

A google service account is required to give proper authentication to GCP for node actions. See [here](https://cloud.google.com/docs/authentication/getting-started) for how to create a service account.
 
**NOTE**: A user with 'resourcemanager.projects.setIamPolicy' permission is required to grant project-level permissions to the service account.
 
After creating the service account you'll need to enable the account using the following: ```export GOOGLE_APPLICATION_CREDENTIALS="<serviceaccount.json>"```


####Azure

**NOTE**: For Azure node killing scenarios, make sure [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) is installed

You will also need to create a service principal and give it the correct access, see [here](https://docs.openshift.com/container-platform/4.5/installing/installing_azure/installing-azure-account.html) for creating the service principal and setting the proper permissions

To properly run the service principal requires “Azure Active Directory Graph/Application.ReadWrite.OwnedBy” api permission granted and “User Access Administrator”

Before running you'll need to set the following: 
1. Login using ```az login```

2. ```export AZURE_TENANT_ID=<tenant_id>```

3. ```export AZURE_CLIENT_SECRET=<client secret>```

4. ```export AZURE_CLIENT_ID=<client id>```
