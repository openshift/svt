# Snappy-move-results Script

The purpose of the Snappy script is to back-up data to the given
snappy data-server.
It accepts two arguments -

```file_path``` -> This is the path to the file which you want to move to Snappy server.

```snappy_file_dir``` -> This is the directory in which you want to store your file in Snappy server.

Running from CLI:

```sh
$ ./run_snappy.sh <file_path> <snappy_file_dir> 
```

## Environment variables

### SNAPPY_DATA_SERVER_URL
Default: ''
The Snappy data server url, where you want to move files.

### SNAPPY_DATA_SERVER_USERNAME
Default: ''
Username for the Snappy data-server.

### SNAPPY_DATA_SERVER_PASSWORD
Default: ''
Password for the Snappy data-server.

