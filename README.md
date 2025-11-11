# trilogy force-latin1-to-utf8

Got a MySQL database with a latin-1 charset that actually stores utf-8 data?

Oops!

This fork of the Trilogy MySQL client "fixes" the "glitch."

Latin-1 database strings are mapped to UTF-8 Ruby strings instead of latin-1,
and that's it.

Otherwise, this fork is identical to the [mainline Trilogy library](https://github.com/trilogy-libraries/trilogy).
