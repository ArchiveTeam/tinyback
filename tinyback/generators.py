# TinyBack - A tiny web scraper
# Copyright (C) 2012 David Triendl
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

"""
tinyback.generators - Module to generate lists of shortcodes

To ensure that each task always consists of the same shortcodes, tinyback uses
different generators that - given one set of input parameters - will always
yield the same sequence of shortcodes.
"""

import hashlib

def factory(generator_type, generator_options):
    """
    Creates a new generator

    Returns a generator of the given type initialized with the specified
    options. Valid types are: chain, list and sequence.
    """
    if generator_type == "chain":
        return chain_generator(generator_options)
    elif generator_type == "sequence":
        return sequence_generator(generator_options)
    elif generator_type == "list":
        return generator_options["list"].__iter__()
    else:
        raise ValueError("Unknown generator %s" % generator_type)

def chain_generator(options):
    """
    Chain generator - Pseudorandom shortcode generation

    The chain generator uses the MD5 hash function to generate a sequence of
    pseudorandom shortcodes. The output of one hash calculation is fed in a
    chain-like manner into the input for the next hash calculation, hence the
    name.

    charset: String with all possible shortcode characters
    count: Number of shortcodes to generate
    length: Length for each generated shortcode
    seed: Random seed for shortcode generation
    """
    if options["length"] > hashlib.md5().digest_size:
        raise ValueError("Length must be shorter than digest size")

    m = 256 - (256 % len(options["charset"]))
    digest = options["seed"]
    count = 0

    while count < options["count"]:
        md5 = hashlib.md5()
        md5.update(digest)
        digest = md5.digest()

        code = ""
        for byte in map(ord, digest):
            if byte > m:
                continue
            code += options["charset"][byte % len(options["charset"])]
            if len(code) == options["length"]:
                count += 1
                yield code
                break

def sequence_generator(options):
    """
    Sequence generator - Sequential shortcode generation

    The sequence generator takes a start and stop code and will generate all
    shortcodes in between in lexicographical order (determinted by the
    charset). Start and stop codes will also be part of the sequence. The
    generator does no error checking - it is up to the user to ensure that
    start comes before stop and that they only contain characters from the
    charset.

    charset: String with all possible shortcode characters
    start: Start sequence with this code
    stop: End sequence with this code
    """
    code = options["start"]
    yield code
    while code != options["stop"]:
        for i in range(len(code) - 1, -1, -1):
            if code[i] == options["charset"][-1]:
                code = code[0:i] + options["charset"][0] + code[i+1:len(code)]
            else:
                code = code[0:i] + options["charset"][options["charset"].index(code[i]) + 1] + code[i+1:len(code)]
                yield code
                break
        else:
            code = options["charset"][0] + code
            yield code
