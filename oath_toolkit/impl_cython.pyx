# -*- coding: utf-8 -*-

from oath_toolkit cimport coath_toolkit as c
from libc cimport stdlib

import atexit

from .exc import OATHError
from .types import OTPPosition

c.oath_init()
atexit.register(lambda: c.oath_done())

cdef int _handle_retval(int retval, bint positive_ok) except -1:
    """
    Handle the ``oath_rc`` return value from a ``liboath`` function call.

    :type retval: int
    :param bool positive_ok: Whether positive integers are acceptable (as is
                             the case in validation functions), or throw
                             exceptions.
    :raises: :class:`OATHError` containing error message on non-OK
             return value.
    """
    if retval != c.OATH_OK and (not positive_ok or retval < 0):
        err_str = c.oath_strerror(retval)
        err = OATHError(err_str)
        err.code = retval
        raise err
    return 0

library_version = c.oath_check_version('0')

cpdef bint check_library_version(bytes version):
    cdef const char *result = c.oath_check_version(version)
    return NULL != result

IF LIBOATH_VERSION >= (2, 0, 0):
    cpdef bytes base32_decode(bytes data):
        """
        Decode Base32 data.

        Unlike :func:`base64.b32decode`, it handles human-readable Base32
        strings. Requires liboath 2.0.

        :param bytes data: The data to be decoded.
        :rtype: bytes
        """
        cdef char* output = NULL
        cdef size_t output_len = 0
        cdef bytes py_string
        _handle_retval(c.oath_base32_decode(<bytes>data, len(data), &output,
                                            &output_len),
                    False)
        try:
            py_string = <bytes>output[:output_len]
        finally:
            stdlib.free(output)
        return py_string

cpdef bytes hotp_generate(bytes secret, unsigned long long moving_factor,
                          unsigned int digits, bint add_checksum,
                          int truncation_offset):
    """
    Generate a one-time password using the HOTP algorithm (:rfc:`4226`).

    :param bytes secret: The secret string used to generate the one-time
                         password.
    :param int moving_factor: unsigned, can be :func:`long`, in theory.
    :param int digits: unsigned, the number of digits of the one-time
                       password.
    :param bool add_checksum: Whether to add a checksum digit (depending
                              on the version of ``liboath`` used, this may
                              be ignored).
    :param int truncation_offset: A truncation offset to use, if not set to a
                                  negative value (which means ``2^32 - 1``).
    :return: one-time password
    :rtype: :func:`bytes`
    """
    cdef char* generated = ''
    if truncation_offset < 0:
        truncation_offset = (2 ** 32) - 1
    retval = c.oath_hotp_generate(secret, len(secret), moving_factor, digits,
                                  add_checksum, truncation_offset, generated)
    _handle_retval(retval, False)
    return <bytes>generated

cpdef hotp_validate(bytes secret, unsigned long long start_moving_factor,
                    unsigned int window, bytes otp):
    """
    Validate a one-time password generated using the HOTP algorithm
    (:rfc:`4226`).

    :param bytes secret: The secret used to generate the one-time password.
    :param int start_moving_factor: unsigned, can be :func:`long`, in
                                    theory. The start counter in the
                                    OTP stream.
    :param int window: The number of OTPs after the start offset OTP
                        to test.
    :param bytes otp: The one-time password to validate.
    :return: The position in the OTP window, where ``0`` is the first
                position.
    :rtype: :class:`oath_toolkit.types.OTPPosition`
    :raise: :class:`OATHError` if invalid
    """
    retval = c.oath_hotp_validate(secret, len(secret), start_moving_factor,
                                  window, otp)
    _handle_retval(retval, True)
    return OTPPosition(absolute=None, relative=retval)

cpdef bytes totp_generate(bytes secret, unsigned long now, int time_step_size,
                          unsigned long time_offset, unsigned int digits):
    """
    Generate a one-time password using the TOTP algorithm (:rfc:`6238`).

    :param bytes secret: The secret string used to generate the one-time
                            password.
    :param int now: The UNIX timestamp (usually the current one)
    :param int time_step_size: Unsigned, the time step system parameter. If
                               set to a negative value, defaults to ``30``.
    :param int time_offset: The UNIX timestamp of when to start counting
                            time steps (usually should be ``0``).
    :param int digits: The number of digits of the one-time password.
    :return: one-time password
    :rtype: :func:`bytes`
    """
    cdef char* generated = ''
    if time_step_size < 0:
        time_step_size = c.OATH_TOTP_DEFAULT_TIME_STEP_SIZE
    retval = c.oath_totp_generate(secret, len(secret), now, time_step_size,
                                  time_offset, digits, generated)
    _handle_retval(retval, False)
    return <bytes>generated

cpdef totp_validate(bytes secret, unsigned long now, int time_step_size,
                    unsigned long start_offset, unsigned int window, bytes otp):
    """
    Validate a one-time password generated using the TOTP algorithm
    (:rfc:`6238`).

    :param bytes secret: The secret used to generate the one-time password.
    :param int now: The UNIX timestamp (usually the current one)
    :param int time_step_size: Unsigned, the time step system parameter. If
                               set to a negative value, defaults to ``30``.
    :param int start_offset: The UNIX timestamp of when to start counting
                             time steps (usually should be ``0``).
    :param int window: The number of OTPs before and after the start OTP
                        to test.
    :param bytes otp: The one-time password to validate.
    :return: The absolute and relative positions in the OTP window, where
                ``0`` is the first position.
    :rtype: :class:`oath_toolkit.types.OTPPosition`
    :raise: :class:`OATHError` if invalid
    """
    cdef int otp_pos
    cdef int* c_otp_pos = &otp_pos
    if time_step_size < 0:
        time_step_size = c.OATH_TOTP_DEFAULT_TIME_STEP_SIZE
    retval = c.oath_totp_validate2(secret, len(secret), now, time_step_size,
                                   start_offset, window, c_otp_pos, otp)
    _handle_retval(retval, True)
    return OTPPosition(absolute=retval, relative=otp_pos)
