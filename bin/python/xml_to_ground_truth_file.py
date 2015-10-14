#!/usr/bin/env python
# -*- coding=utf8 -*-

"""
    xml_to_ground_truth.py
    Vincent Dowling

     Takes an xml ground truth input file and writes it to a flat output file
     Format of output file --> "QuestionId\tQuestion\tPAU_ID"
"""

from lxml.etree import parse
import re
import argparse
from sys import stderr, stdout
import sys
from os import path
import json

# Log/error functions
log = lambda msg: stdout.write("[python] %s\n" % str(msg))
error = lambda msg: stderr.write("[python] %s\n" % str(msg))


def get_primaries(root):
    question_dict = dict()
    for child in root.iterchildren():
        question, qid = child.attrib['text'], child.attrib['id'] # Assume: every question has these
        for gc in child.iterchildren():
            if re.match('^.*pau$', gc.tag):
                pau_id = gc.attrib['tid'] # Assumes: every PAU element has 'tid'
                question_dict[qid] = ([(qid, question)], pau_id)
    return question_dict


def add_secondaries(root, question_map):
    for child in root.iterchildren():
        question, qid = child.attrib['text'], child.attrib['id']
        for gc in child.iterchildren():
            if re.match('^.*mappedQuestion', gc.tag):
                mapped_id = gc.attrib['id'] # Assume: every mapped question has 'id'
                if mapped_id not in question_map.keys():
                    log("Could not find root question for question=%r" % question)
                else:
                    question_map[mapped_id][0].append((qid, question))


def write_output(question_map, output_path, remove_escape):
    questions_written = 0
    log("Writing questions to output_file=%s..." % str(output_path))
    with open(output_path, 'wt') as outfile:
        for (questions, pau_id) in question_map.itervalues():
            for (qid, question) in questions:
                try:
                    if not remove_escape or not question_has_escape_characters(question):
                        output_str = "%s\t%s\t%s\n" % (qid, question, pau_id)
                        outfile.write(output_str.encode(encoding='utf8'))
                        questions_written += 1
                    elif question_has_escape_characters(question):
                        log("Did not write question=%s because it had escape chars" % question)
                except UnicodeEncodeError, e:
                    log("EncodeError in writing question=%r : %r" % (question, e))
                except Exception, e:
                    log("Exception in writing question=%r : %r" % (question, e))
    log("%d questions written to output_file..." % questions_written)


def filter_by_content(question_dict, pau_ids):
    """ Filter question clusters that are not in the content dict"""
    modified_dict = dict()
    for (qid, (questions, pau_id)) in question_dict.iteritems():
        if pau_id in pau_ids:
            modified_dict[qid] = (questions, pau_id)
    return modified_dict


def question_has_escape_characters(question):
    return re.match('^.*[:&].*$', question)


def parse_args():
    """ Parse command line arguments """
    parser = argparse.ArgumentParser(description='Convert an XML file into a CSV file')
    parser.add_argument('-i', type=str)
    parser.add_argument('-o', type=str)
    parser.add_argument('-c', '--content-file', type=str, default=None)
    parser.add_argument('--remove-escape', action='store_true', default=False)
    parser.add_argument('--primary-only', action='store_true', default=False)
    ns = parser.parse_args()
    return ns.i, ns.o, ns.content_file, ns.remove_escape, ns.primary_only


def main():
    """ Main script """
    input_path, output_path, content_file, remove_escape, primary_only = parse_args()
    root = parse(input_path).getroot()
    question_dict = get_primaries(root)    
    log("Number of Primary Questions : %d" % len(question_dict))
    if not primary_only:
        add_secondaries(root, question_dict)
        log("Total Number of Questions : %d" % sum(len(qs) for (qs, pau_id) in question_dict.itervalues()))

    if content_file and path.isfile(content_file):
        with open(content_file, 'rt') as infile:
            pau_ids = {e['pauId'] for e in json.load(infile)}
        log("Filtering ground truth based on content_file=%r..." % content_file)
        question_dict = filter_by_content(question_dict, pau_ids)
        log("Total Number of Questions after filtering : %d" % sum(len(qs) for (qs, pau_id) in question_dict.itervalues()))
    write_output(question_dict, output_path, remove_escape)


if __name__ == "__main__":
    try:        
        log("Entering %s" % __file__)
        main()
        log("Exiting %s with status code 0" % __file__)
        sys.exit(0)
    except Exception, e:
        error("Exception in main() method. Exception : %r" % (e.message if hasattr(e, 'message') else e))
        log("Exiting %s with status code 1" % __file__)
        sys.exit(1)
