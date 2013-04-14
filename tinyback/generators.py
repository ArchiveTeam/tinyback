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

import hashlib

def factory(generator_type, generator_options):
    if generator_type == "chain":
        return chain_generator(generator_options)
    elif generator_type == "sequence":
        return sequence_generator(generator_options)
    elif generator_type == "list":
        return generator_options["list"].__iter__()
    else:
        raise ValueError("Unknown generator %s" % generator_type)

def chain_generator(options):
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
