#!/usr/bin/python
# vim: set ts=4 sts=4 sw=4 et:

import sys
import subprocess
import re

try:
    import biplist
except ImportError:
    print 'Please install the `biplist` module:'
    print '    sudo easy_install biplist'
    sys.exit(1)

try:
    import argparse
except:
    print 'Cannot find library "argparse"!'
    print 'Please do either:'
    print '    sudo apt-get install python-argparse'
    print '    sudo easy_install argparse'
    print '    sudo pip install argparse'
    print '    Go to https://pypi.python.org/pypi/argparse'
    sys.exit(1)

SDK_ROOT = '/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk'
PRINT_FILENAMES = True
STRIP_FILENAMES = True # remove SDK_ROOT prefix
KEY_VALUE_PATTERN = '\t%s =\t%s'

LANGUAGE_REGEX = re.compile(r'^(.*/)([^/]+)(\.lproj/.*)$')

def stripFilenameIfNeeded(fn):
    if STRIP_FILENAMES:
        return fn[len(SDK_ROOT) + 1:]
    else:
        return fn

def extractLanguage(fileName):
    matches = LANGUAGE_REGEX.match(fileName)
    if matches is None:
        return
    return matches.group(2)

def yieldAllDicts(pathPattern = None):
    cmdline = ['/usr/bin/find', SDK_ROOT, '-type', 'f', '(', '-name', '*.strings', '-o', '-name', '*.plist', ')']
    if pathPattern is not None:
        cmdline.append('-path')
        cmdline.append(pathPattern)
    proc = subprocess.Popen(cmdline, stdout=subprocess.PIPE)
    while True:
        line = proc.stdout.readline()
        if line == '':
            break
        fn = line.rstrip()
        plists = biplist.readPlist(fn)
        if type(plists) is not list:
            plists = [plists]
        for plist in plists:
            if type(plist) is str or type(plist) is unicode:
                plist = { '____NO____KEY____': plist }
            if 'iteritems' not in dir(plist):
                print stripFilenameIfNeeded(fn)
                print 'Unexpected type:', type(plist)
                print repr(plist)
                continue
            yield (fn, plist)

def yieldSiblingDicts(siblingFile):
    matches = LANGUAGE_REGEX.match(siblingFile)
    if matches is None:
        return
    for fn, plist in yieldAllDicts(SDK_ROOT + '/' + matches.group(1) + '*' + matches.group(3)):
        yield fn, plist

def listLanguages(siblingFile):
    for fn, plist in yieldSiblingDicts(siblingFile):
        yield extractLanguage(fn)

def listAllTranslations(siblingFile, key):
    for fn, plist in yieldSiblingDicts(siblingFile):
        if key in plist:
            print extractLanguage(fn) + KEY_VALUE_PATTERN % (key, plist[key])

def searchInValues(what):
    for fn, plist in yieldAllDicts():
        fnPrinted = False
        for k, v in plist.iteritems():
            if type(v) is not str and type(v) is not unicode:
                continue
            if ((type(what) is str or type(what) is str) and what in v) or (what.match(v) is not None):
                if not fnPrinted:
                    print stripFilenameIfNeeded(fn)
                    fnPrinted = True
                print '\t%s =\t%s' % (k, v)

def searchInKeys(what):
    for fn, plist in yieldAllDicts():
        fnPrinted = False
        for k, v in plist.iteritems():
            if type(v) is not str and type(v) is not unicode:
                continue
            if ((type(what) is str or type(what) is unicode) and what == k) or (what.match(k) is not None):
                if not fnPrinted:
                    print stripFilenameIfNeeded(fn)
                    fnPrinted = True
                print '\t%s =\t%s' % (k, v)

def searchKey(key):
    for fn, plist in yieldAllDicts():
        fnPrinted = False
        for k, v in plist.iteritems():
            if type(v) is not str:
                continue
            if k == key:
                if not fnPrinted:
                    print stripFilenameIfNeeded(fn)
                    fnPrinted = True
                print '\t%s =\t%s' % (k, v)

def parseArgs(argv = None, **kwargs):
    parser = argparse.ArgumentParser(
            formatter_class=argparse.RawDescriptionHelpFormatter,
            conflict_handler='resolve',
            description='iOS translations extractor utility',
            epilog='''\
Finds and extracts translations for the iOS SDK.''')
    parser.add_argument('command', type=str, choices=['values', 'keys', 'key', 'languages', 'translations'], help='Command to execute')
    parser.add_argument('what', type=str, help='Value or file name')
    parser.add_argument('-f', '--file', type=str, dest='file', help='Accessory filename')
    parser.add_argument('-E', '--regex', action='store_true', dest='regex', help='Whether `what` is a regex instead of a regular string')
    if argv is None:
        argv = sys.argv[1:]
    argv_toParse = argv[:]
    argv_toParse.extend(['--%s' % key.replace('_', '-') for key, value in kwargs.iteritems() if value == True])
    argv_toParse.extend(['--%s=%s' % (key.replace('_', '-'), value) for key, value in kwargs.iteritems() if type(value) != bool])
    args = parser.parse_args(argv_toParse)
    return args

def main(args):
    if args.regex:
        args.what = re.compile(args.what)
    if args.command == 'values':
        searchInValues(args.what)
    elif args.command == 'keys':
        searchInKeys(args.what)
    elif args.command == 'key':
        searchKey(args.what)
    elif args.command == 'languages':
        for lang in listLanguages(args.what):
            print lang
    elif args.command == 'translations':
        if args.file is None:
            raise Exception('Missing --file argument')
        listAllTranslations(args.file, args.what)
    else:
        raise Exception('Unknown command')

if __name__ == '__main__':
    try:
        main(parseArgs(sys.argv[1:]))
    except KeyboardInterrupt:
        pass
