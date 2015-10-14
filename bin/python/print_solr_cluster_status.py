import sys, requests
try:
    URL, USERNAME, PASSWORD, CLUSTER_ID = sys.argv[1:5]
    resp = requests.get("%s/v1/solr_clusters/%s" % (URL, CLUSTER_ID), auth=(USERNAME, PASSWORD))
    status = resp.json()["solr_cluster_status"].strip()
    print status
except Exception, e:
    print "NOT READY"
