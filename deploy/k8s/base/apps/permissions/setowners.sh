#! /bin/sh
# NOTE: MongoDB uses Atlas (cluster-mereka-lms.2pjex4s.mongodb.net), no local volume needed
setowner $OPENEDX_USER_ID /mounts/lms /mounts/cms /mounts/openedx
setowner 1000 /mounts/elasticsearch
setowner 999 /mounts/mysql
setowner 1000 /mounts/redis

setowner 1000 /mounts/notes
setowner 1000 /mounts/xqueue