#!/usr/bin/env python

import boto3
import argparse

def main():
    parser = argparse.ArgumentParser(description="Script to delete EBS volume - based on tag it has")
    parser.add_argument("--tagname", help="tagname which is used by EBS volume", required=True)

    args = parser.parse_args()
    tagname = args.tagname

    ec2 = boto3.resource("ec2")
    def delete_ebs():
        global tagname
        tagname = args.tagname

        volumestag = ec2.volumes.filter(Filters=[{'Name' : 'tag-value', 'Values':[tagname]}])
        # for keys it would be ec2.volumes.filter(Filters=[{'Name' : 'tag-key', 'Values':[tagkey]}])
        for volume in volumestag:
            print ("Deleting volume:", volume.id)
            volume.delete(DryRun=False)

    delete_ebs()


if __name__ == '__main__':
    main()

