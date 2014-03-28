# RBHive changelog

Versioning prior to 0.5.3 was not tracked, so this changelog only lists changes introduced after 0.5.3.

## 0.6.0

0.6.0 introduces one backwards-incompatible change:

* Behaviour change: RBHive will no longer coerce the strings "NULL" or "null" to the Ruby `nil`; the rationale
  for this change is that it introduces hard to trace bugs and does not seem to make sense from a logical
  perspective (Hive's "NULL" is a very different thing to Ruby's `nil`).

0.6.0 introduces support for Hive 0.13, and for the Hive 0.11 version shipped with CDH5 Beta 1 and Beta 2:

* Thrift protocol bindings updated to include all the protocols shipped with the Hive 0.13 release.
* Allow the user to choose a protocol explicitly; provided helper symbols / lookups for common protocols (e.g. CDH4, CDH5)