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

class ServiceException(Exception):
    """
    All Service-related exceptions are derived from this class.
    """

class FetchException(ServiceException):
    """
    Raised when fetch operation fails.
    """

class BlockedException(ServiceException):
    """
    Raised when the URL shortenner is blocking your requests.
    """

class NoRedirectException(ServiceException):
    """
    Raised when a shortcude does not have a long URL.
    """

class CodeBlockedException(NoRedirectException):
    """
    Raised when a shortcode has been blocked by the URL shortener.
    """
