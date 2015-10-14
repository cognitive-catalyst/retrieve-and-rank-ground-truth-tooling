#!/usr/bin/env python
# -*- coding=utf8 -*-

import sys, json
try:
    str_resp, collection_name = sys.argv[1:3]
    obj_resp = json.loads(str_resp)
    existing_collections = obj_resp['collections']
    if collection_name in existing_collections:
        print "CONTAIN"
    else:
        print "NO_CONTAIN"
except Exception, e:
    print "UNRESOLVED"
