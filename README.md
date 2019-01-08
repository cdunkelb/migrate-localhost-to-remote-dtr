# migrate-localhost-to-remote-dtr

This script will read from the local dtr volumes and create a list of images and repos to be pushed to another remote DTR.

OLD-UCP-DTR - UCP node of the OLD Cluster that is running DTR (i.e. DTR containers, and volumes)
OLD-UCP-MAN - UCP Manager node of the OLD cluster
NEW-UCP DTR - UCP node of the NEW Cluster that is running DTR (i.e. DTR containers, and volumes)
NEW-UCP-MAN - UCP Manager node of the OLD cluster

1. On OLD-UCP-DTR: run a `docker login NEW-UCP-DTR` and push a test image to the NEW DTR
2. Copy the script `create⎽dtr⎽repos⎽from⎽a⎽list.sh` to the OLD-UCP-DTR node.
3. Run `sudo ./migrate⎽localhost⎽dtr⎽to⎽remote.sh`
4. Enter the URL for the NEW-UCP-DTR node
5. Enter the Username and password for an admin user on the NEW cluster.


