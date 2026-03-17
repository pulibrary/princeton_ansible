#!/usr/bin/env python
"""
BagIt and LOCKSS: "Bad" Filename Finder
by Stephen Eisenhauer
last updated 2013-08-19

This tool will recursively scan a directory for filenames that violate a set
of naming standards meant to prevent problems when ingesting collections into
LOCKSS over HTTP.  The relative paths will be printed to standard output; No
files are moved or modified by this tool.

If -v or --verbose is provided, the reasons for the results being matched will
be printed with the output.

Usage:
  find-bad-files.py [-h|--help] [-v|--verbose] <directory>
"""
import argparse
import os
import re


rules = {
    "Thumbs.db": {
        "regex": "[Tt]humbs\.db$",
        "match": False
    },
    "Leading Punctuation": {
        "regex": "[a-zA-Z0-9]+.*",
        "match": True
    },
    "Non-URL-safe": {
        "regex": "[a-zA-Z0-9\.\_/-]+$",
        "match": True
    }
}


def _make_arg_parser():
    parser = argparse.ArgumentParser(
        description='Tools for generating BagIt Change Bags.')
    parser.add_argument('directory',
                        help="path to the directory to be scanned")
    parser.add_argument('-v', '--verbose', action="store_true",
                        help="print more detailed information in results")

    return parser


if __name__ == "__main__":
    # Arguments
    parser = _make_arg_parser()
    args = parser.parse_args()
    directory = os.path.abspath(args.directory)

    # Set up dict for matches
    matches = {}
    for rulename, rule in rules.items():
        matches[rulename] = []

    # Loop over the directory contents and test the filenames
    for root, dirnames, filenames in os.walk(directory):
        for filename in filenames + dirnames:
            # If this file or dir name matches a rule, print it.
            for rulename, rule in rules.items():
                if bool(re.match(rule['regex'], filename)) != rule['match']:
                    matches[rulename].append(os.path.join(root, filename))
                    break  # No need to check this file for other violations

    # Print the results
    for category, filenames in matches.items():
        if len(filenames) > 0:
            if args.verbose:
                print "=== %s ===" % category
            for filename in filenames:
                print filename
