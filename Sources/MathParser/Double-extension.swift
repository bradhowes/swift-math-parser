// Copyright © 2022 Brad Howes. All rights reserved.

#if canImport(Darwin)
import Darwin.C
public extension Double {
  // swiftlint:disable:next identifier_name
  static var e: Self { Darwin.M_E }
}
#elseif canImport(Glibc)
import Glibc
public extension Double {
  // swiftlint:disable:next identifier_name
  static var e: Self { Glibc.M_E }
}
#else
public extension Double {
  // swiftlint:disable:next identifier_name
  static var pi: Self { 3.14159265358979323846264338327950288 }
  // swiftlint:disable:next identifier_name
  static var e: Self { 2.71828182845904523536028747135266250 }
}
#endif
