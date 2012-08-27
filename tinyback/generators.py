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
