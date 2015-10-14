#!/usr/bin/env python
# -*- coding=utf8 -*-

"""
    split_train_test.py
    Vincent Dowling

    File that takes an input file and splits into train/test files
"""


from os import path as osp
import argparse
import re
from sys import stdout, stderr
import sys
from numpy import random
from io import open

# Log/error functions
log = lambda msg: stdout.write("[python] %s\n" % str(msg))
error = lambda msg: stderr.write("[python] %s\n" % str(msg))


def ask_for_percentage():
    " Ask user for percentage of questions "
    while True:
        str_perc = raw_input('Enter desired Decimal Ratio of Train/Test Questions : ')
        try:
            float_perc = float(str_perc)
            if float_perc > 0.00 and float_perc < 1.00:
                return float_perc
            else:
                print "Percentage is not between 0.00 and 1.0. Please enter another number"
        except ValueError, e:
            print "Please enter a valid decimal between 0.00 and 1.00"


def parse_args():
    parser = argparse.ArgumentParser(description='Convert an XML file into a CSV file')
    parser.add_argument('-i', '--input-file', type=str)
    parser.add_argument('-p', '--train-percentage', default=0.65, type=float)
    parser.add_argument('--ask-for-percentage', action='store_true', default=False)
    ns = parser.parse_args()
    input_path, train_perc = ns.input_file, ns.train_percentage
    if ns.ask_for_percentage:
        train_perc = ask_for_percentage()

    if not osp.isfile(input_path):
        raise ValueError("Input file %s was not found" % input_path)
    elif train_perc < 0.0 or train_perc > 1.0:
        raise ValueError("Train percentage must be between 0.0 and 1.0")
    else:
        return input_path, train_perc


def main(args):
    """
        Main method
        Split the lines in to test/train and write to different files
    """

    input_path, train_perc = args
    dir_name = osp.dirname(osp.abspath(input_path))
    bfm = re.match('^(.*)[.](.*)$', osp.basename(input_path))
    base, ext = bfm.group(1), bfm.group(2)
    train_path = osp.join(dir_name, "%s_train.%s" % (base, ext))
    test_path = osp.join(dir_name, "%s_test.%s" % (base, ext))

    with open(input_path, mode='rt', encoding='utf8') as infile,\
        open(train_path, mode='wt', encoding='utf8') as train_file,\
        open(test_path, mode='wt', encoding='utf8') as test_file:

        # Split lines
        lines = infile.read().split("\n")
        log("Total Number of Questions : %d" % len(lines))
        num_lines = len(lines); cutoff = int(train_perc * num_lines)
        log("Total Number of Training Questions : %d" % cutoff)
        log("Total Number of Test Questions : %d" % (num_lines - cutoff))
        indices = range(num_lines); random.shuffle(indices)

        # Write to train file
        for index in indices[:cutoff]:
            train_file.write("%s\n" % lines[index])

        # Write to test file
        for index in indices[cutoff:]:
            test_file.write("%s\n" % lines[index])


if __name__ == "__main__":
    try:
        args = parse_args()
        main(args)
        log("Exiting with status code 0")
        sys.exit(0)
    except Exception, e:
        error("Exception : %r" % e.message)
        log("Exiting with status code 1")
        sys.exit(1)
