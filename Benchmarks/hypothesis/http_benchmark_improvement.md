# HTTP URI Benchmark Improvement Hypotheses

## Hypothesis 1: ASCII Fast Path for Single-Character Delimiter Lookups

**Date**: 2025-12-24

**Observation**:
The `Parser.read(until: Unicode.Scalar)` method is heavily used during URI parsing for delimiters like `?`, `/`, `#`, `:`, `&`, `=`. Currently, it calls `unsafeCurrent()` which invokes `decodeUTF8Character()` - a complex UTF8 decoding function that handles multi-byte characters.

**Hypothesis**:
For ASCII delimiters (single byte, value < 128), we can skip full UTF8 decoding and directly compare the byte value. Since URI delimiters are always ASCII, this should provide significant speedup in the parsing hot path.

**Implementation**:
Add a fast path in `read(until: Unicode.Scalar)` that checks if the target character is ASCII, and if so, compares bytes directly instead of decoding UTF8.

**Expected Impact**:
- `HTTP:URI:Decode:*` benchmarks should improve (fewer instructions per character scan)
- `HTTP:URI:QueryParameters:*` benchmarks should improve (query parsing uses `&` and `=` delimiters)

**Result**: SUCCESS

| Benchmark | Time Improvement (p50) | Instructions Improvement (p50) |
|-----------|------------------------|-------------------------------|
| HTTP:URI:Decode | 17% | 19% |
| HTTP:URI:Decode:FullURL | **53%** | **54%** |
| HTTP:URI:Decode:LongPath | 20% | 23% |
| HTTP:URI:Decode:PathOnly | 3% | 10% |
| HTTP:URI:QueryParameters | 6% | 8% |
| HTTP:URI:QueryParameters:Many | 2% | 8% |
| HTTP:URI:QueryParameters:NoPercentEncoding | 9% | 8% |

The biggest improvement was on full URLs which use the character set parsing for host/port detection.

---

## Hypothesis 2: Optimize `read(untilString:)` for Short ASCII Strings

**Date**: 2025-12-24

**Observation**:
The `read(untilString: "://")` method is called during scheme detection for URIs that don't start with "/". The current implementation:
1. Creates a mutable copy of the search string
2. Uses `withUTF8` closure which adds overhead
3. Has generic string matching logic

For short ASCII strings like "://", we can use a more direct approach.

**Hypothesis**:
Add a fast path for short ASCII search strings (up to 4 bytes) that:
1. Extracts bytes at call time without closure overhead
2. Uses direct byte comparison in the loop
3. Avoids the mutable string copy

**Expected Impact**:
- `HTTP:URI:Decode:FullURL` should improve further (scheme detection uses "://")
- `HTTP:URI:Decode` should improve slightly (also uses scheme detection path on some iterations)

**Result**: SUCCESS (Marginal additional improvement)

Combined results with Hypothesis 1 (cumulative improvement vs baseline):

| Benchmark | Time Improvement (p50) | Instructions Improvement (p50) |
|-----------|------------------------|-------------------------------|
| HTTP:URI:Decode:FullURL | **51%** | **51%** |
| HTTP:URI:Decode:LongPath | 25% | 23% |
| HTTP:URI:Decode | 18% | 19% |
| HTTP:URI:QueryParameters:NoPercentEncoding | 10% | 8% |
| HTTP:URI:Decode:PathOnly | 7% | 10% |
| HTTP:URI:QueryParameters | 7% | 8% |
| HTTP:URI:QueryParameters:Many | 5% | 8% |

Key observations:
- PathOnly improved from 3% (H1 alone) to 7% with H2
- LongPath improved from 20% (H1 alone) to 25% with H2
- The optimization helps by avoiding closure overhead in `read(untilString:)`

---

## Hypothesis 3: Optimize `split()` Method - Avoid Exception Handling

**Date**: 2025-12-24

**Observation**:
The `split(separator:)` method uses try/catch for flow control when reading until a separator. When the separator is not found (end of string), an exception is thrown and caught. Exception handling has overhead compared to a simple boolean check.

Current implementation:
```swift
package mutating func split(separator: Unicode.Scalar) -> [Parser] {
    var subParsers: [Parser] = []
    while !self.reachedEnd() {
        do {
            let section = try read(until: separator)
            subParsers.append(section)
            unsafeAdvance()
        } catch {
            if !self.reachedEnd() {
                subParsers.append(self.readUntilTheEnd())
            }
        }
    }
    return subParsers
}
```

**Hypothesis**:
Use the existing `throwOnOverflow: false` parameter to avoid exception handling. The `read(until:)` method already returns the content read even when throwOnOverflow is false, so we can check if we reached the end instead of catching exceptions.

Additionally, for ASCII separators, we can do a quick pre-count to estimate array capacity, reducing dynamic array growth overhead.

**Expected Impact**:
- `HTTP:URI:QueryParameters:*` benchmarks should improve (uses `split(separator: "&")`)

**Result**: SUCCESS

| Benchmark | Time Improvement (p50) | Instructions Improvement (p50) | Malloc Improvement (p50) |
|-----------|------------------------|-------------------------------|-------------------------|
| HTTP:URI:QueryParameters | **15%** | **17%** | **43%** (7→4) |
| HTTP:URI:QueryParameters:Many | **13%** | **14%** | **56%** (9→4) |
| HTTP:URI:QueryParameters:NoPercentEncoding | **15%** | **17%** | **43%** (7→4) |

Key observations:
- Significant malloc reduction from pre-allocation with `reserveCapacity()`
- The `:Many` variant with 10 query parameters shows 56% fewer allocations (9→4)
- Both time and instruction counts improved by 13-17%
- URI decode benchmarks also show minor improvements (5-9%) as side benefit

---

## Hypothesis 4: Optimize queryParameters Parsing - Avoid Exception Handling

**Date**: 2025-12-24

**Observation**:
The `queryParameters` getter uses try/catch for each query parameter when parsing key=value pairs:

```swift
let queryKeyValues = queries.map { query -> (key: Substring, value: Substring) in
    do {
        var query = query
        let key = try query.read(until: "=")
        // ...
    } catch {
        return (key: query.string[...], value: "")
    }
}
```

This has several inefficiencies:
1. Exception handling overhead for each parameter
2. Creates intermediate array with `map` before passing to FlatDictionary
3. Multiple closure invocations

**Hypothesis**:
1. Use `throwOnOverflow: false` to avoid exception handling
2. Build FlatDictionary directly using `reserveCapacity` and `append` instead of intermediate array
3. Use a simple loop instead of `map` closure

**Expected Impact**:
- `HTTP:URI:QueryParameters:*` benchmarks should improve further

**Result**: PARTIAL - Reverted incremental approach, kept throwOnOverflow fix

Initial attempt with incremental `FlatDictionary.append()` caused significant regression:
- QueryParameters: -25% time, -75% more mallocs (4→7)
- QueryParameters:Many: -36% time, -175% more mallocs (4→11)

**Root cause**: `FlatDictionary.append()` grows internal arrays incrementally, causing more allocations than passing a pre-sized array to `FlatDictionary.init()`.

**Final approach**: Kept `map` + `FlatDictionary.init(queryKeyValues)` pattern but replaced try/catch with `throwOnOverflow: false`. This preserves the pre-allocation benefit while removing exception handling overhead.

---
