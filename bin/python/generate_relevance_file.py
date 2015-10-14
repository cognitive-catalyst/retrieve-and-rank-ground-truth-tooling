#!/usr/bin/env python
# -*- coding=utf8 -*-

"""
    Vincent Dowling
    Watson Ecosystem

    python bin/python/generate_relevance_file.py -i <gt_input_file> -o <relevance_output_file>
    Script that creates a relevance file based on a tab delimited input file
"""

# Runtime imports
import sys
from sys import stderr, stdout
import argparse
import csv
import os


# Loggers
log = lambda msg: stdout.write("[python] %s\n" % str(msg))
error = lambda msg: stderr.write("[python] %s\n" % str(msg))


def parse_args():
    "Parse command line arguments"
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--gt-input-file', type=str, help='Path to the ground_truth_input_file')
    parser.add_argument('-o', '--relevance-output-file', type=str, help='Path to the CSV output_relevance_file')
    ns = parser.parse_args()
    if not os.path.isfile(ns.gt_input_file):
        raise ValueError("Input File %s is not an existing file" % str(ns.gt_input_file))
    elif not ns.relevance_output_file.endswith('csv'):
        raise ValueError("CSV Output File %s is not a CSV file" % str(ns.relevance_output_file))
    else:
        return ns.gt_input_file, ns.relevance_output_file


def main():
    "Main script"
    gt_input_path, relevance_output_path = parse_args()
    with open(gt_input_path, 'rt') as infile, open(relevance_output_path, 'wt') as outfile:
        reader = csv.reader(infile, delimiter='\t')
        writer = csv.writer(outfile, delimiter=',', quotechar='"', quoting=csv.QUOTE_ALL)
        for row in reader:
            if len(row) != 3:
                log("Row=%r did not contain exactly 3 elements" % row)
            else:
                out_row = [row[1], row[2], "1"]
                writer.writerow(out_row)
    log("Relevance file written to path=%r..." % relevance_output_path)


if __name__ == "__main__":
    try:
        main()
        log("Exiting with status code 0")
        sys.exit(0)
    except Exception, e:
        error("Exception in main() method. Message : %r" % e.message if hasattr(e, 'message') else e)
        log("Exiting with status code 1")
        sys.exit(1)
