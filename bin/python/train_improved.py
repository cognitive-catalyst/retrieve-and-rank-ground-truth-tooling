#!/usr/bin/env python
import csv
import subprocess
import json
import shlex
import os
import sys
import getopt

#remove the ranker training file (just in case it's left over from a previous run)
TRAININGDATA='trainingdata.txt'
try:
    os.remove(TRAININGDATA)
except OSError:
    pass

CREDS=''
CLUSTER=''
COLLECTION=''
RELEVANCE_FILE=''
RANKERNAME=''
ROWS='10'
DEBUG=False
VERBOSE=''

from sys import stdout, stderr
log = lambda msg: stdout.write("[python] %s\n" % str(msg))
error = lambda msg: stderr.write("[python] %s\n" % str(msg))


def usage():
    log('train.py -u <username:password> -i <query relevance file> -c <solr cluster> -x <solr collection> -r [option_argument <solr rows per query>] -n <ranker name> -d [enable debug output for script] -v [ enable verbose output for curl]')

try:
    opts, args = getopt.getopt(sys.argv[1:],"hdvu:i:c:x:n:r:",["user=","inputfile=","cluster=","collection=","name=","rows="])
except getopt.GetoptError as err:
    print str(err)
    print usage()
    sys.exit(2)
for opt, arg in opts:
    if opt == '-h':
        usage()
        sys.exit()
    elif opt in ("-u", "--user"):
        CREDS = arg
    elif opt in ("-i", "--inputfile"):
        RELEVANCE_FILE = arg
    elif opt in ("-c", "--cluster"):
        CLUSTER = arg
    elif opt in ("-x", "--collection"):
        COLLECTION = arg
    elif opt in ("-n", "--name"):
        RANKERNAME = arg
    elif opt in ("-r", "--rows"):
        ROWS = arg
    elif opt == '-d':
        DEBUG = True
    elif opt == '-v':
        VERBOSE = '-v'

if not RELEVANCE_FILE or not CLUSTER or not COLLECTION or not RANKERNAME:
    log('Required argument missing.')
    usage()
    sys.exit(2)

log("Input file is %s" % (RELEVANCE_FILE))
log("Solr cluster is %s" % (CLUSTER))
log("Solr collection is %s" % (COLLECTION))
log("Ranker name is %s" % (RANKERNAME))
log("Rows per query %s" % (ROWS))

#constants used for the SOLR and Ranker URLs
BASEURL="https://gateway.watsonplatform.net/retrieve-and-rank/api/v1/"
SOLRURL= BASEURL+"solr_clusters/%s/solr/%s/fcselect" % (CLUSTER, COLLECTION)
RANKERURL=BASEURL+"rankers"

with open(RELEVANCE_FILE, 'rb') as csvfile:
    add_header = 'true'
    question_relevance = csv.reader(csvfile)
    with open(TRAININGDATA, "a") as training_file:
        log('Generating training data...')
        for i, row in enumerate(question_relevance):
            question = row[0]
            relevance = ','.join(row[1:])
            curl_cmd = 'curl -k -s %s -u %s -d "q=%s&gt=%s&generateHeader=%s&rows=%s&returnRSInput=true&wt=json" "%s"' % (VERBOSE, CREDS, question, relevance, add_header, ROWS, SOLRURL)
            if DEBUG:
                print (curl_cmd)
            process = subprocess.Popen(shlex.split(curl_cmd), stdout=subprocess.PIPE)
            output = process.communicate()[0]
            if DEBUG:
               print (output)
            try:
                parsed_json = json.loads(output)
                training_file.write(parsed_json['RSInput'])
            except Exception, e:
                log("Exception when retrieving features for question=%r. Exception : %r" % (question, e))
            finally:
                if i % 50 == 0:
                    log("%d questions retrieved " % i)
            add_header = 'false'
log('Generating training data complete...')

# Train the ranker with the training data that was generate above from the query/relevance input     
ranker_curl_cmd = 'curl -k -X POST -u %s -F training_data=@%s -F training_metadata="{\\"name\\":\\"%s\\"}" %s' % (CREDS, TRAININGDATA, RANKERNAME, RANKERURL)
if DEBUG:
    log(ranker_curl_cmd)
log('Submitting file=%r to train the ranker...' % TRAININGDATA)
process = subprocess.Popen(shlex.split(ranker_curl_cmd), stdout=subprocess.PIPE)
response = process.communicate()[0]
log("Response from ranker : %r" % response)
sys.exit(0)
