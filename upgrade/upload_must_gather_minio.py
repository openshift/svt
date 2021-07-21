# Import MinIO library.
from minio import Minio
#from minio.error import (ResponseError, BucketAlreadyOwnedByYou, BucketAlreadyExists)
import datetime
import time

def upload_must_gather(filepath):
    # Initialize minioClient with an endpoint and access/secret keys.
    minioClient = Minio('10.73.131.57:9000',
                    access_key='openshift',
                    secret_key='am5bM2Es8SRYe$^A',
                    secure=False)
    # Make a bucket with the make_bucket API call.
    '''
    try:
        minioClient.make_bucket("openshift-must-gather", location="us-east-1")
    except BucketAlreadyOwnedByYou as err:
       pass
    except BucketAlreadyExists as err:
       pass
    except ResponseError as err:
       raise
    '''
    # Put an object 'pumaserver_debug.log' with contents from 'pumaserver_debug.log'.

    try:
        #print "upload_filepath=",filepath
        now = datetime.datetime.now()
        dirname=now.strftime("%Y-%m-%d-%H-%M-%S")
        filename=filepath.split("/")[-1]
        object_name = dirname + "/" + filename

        minioClient.fput_object('openshift-must-gather', object_name, filepath)
        url = minioClient.presigned_get_object('openshift-must-gather', object_name)
        print("%s uploaded as %s, download link %s" % (filepath, object_name, url))
        return(object_name)
    except ResponseError as err:
        print(err)
    '''
    try:
        minioClient.remove_object('openshift-must-gather', 'testfile')
    except ResponseError as err:
        print(err)
    '''
