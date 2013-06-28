# -*- coding: utf-8 -*-
#
# Copyright 2013 Mark Lee
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from __future__ import absolute_import

from . import uri
from qrcode import QRCode


def generate(oath, key_type, key, user, issuer, counter=None):
    '''
    Generates a QR code suitable for Google Authenticator.
    See: https://code.google.com/p/google-authenticator/wiki/KeyUriFormat

    :param OATH oath: OATH object
    :param str key_type: the auth type, either ``totp`` or ``hotp``
    :param str key: the string used to generate the secret key
    :param str user: the username
    :param str issuer: issuer name
    :param int counter: initial counter value (HOTP only)
    :returns: a tuple of (secret, image object)
    :rtype: (:class:`str`, :class:`pillow:PIL.Image.Image`)
    '''
    qr = QRCode()
    secret, oath_uri = uri.generate(oath, key_type, key, user, issuer, counter)
    qr.add_data(oath_uri)
    return secret, qr.make_image()