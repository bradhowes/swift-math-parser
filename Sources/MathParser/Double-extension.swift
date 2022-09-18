// Copyright © 2021 Brad Howes. All rights reserved.

#if canImport(Darwin)
import Darwin.C
public extension Double {
  static var e: Self { Darwin.M_E }
}
#elseif canImport(Glibc)
import Glibc
public extension Double {
  static var e: Self { Glibc.M_E }
}
#else
public extension Double {
  static var pi: Self { 3.14159265358979323846264338327950288 }
  static var e: Self { 2.71828182845904523536028747135266250 }
}
#endif
