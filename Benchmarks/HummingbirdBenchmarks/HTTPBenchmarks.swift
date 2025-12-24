//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2025 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Benchmark
@_spi(Internal) import Hummingbird
import HummingbirdCore

func httpBenchmarks() {
    // MARK: - URI Parsing Benchmarks

    Benchmark("HTTP:URI:Decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test/this/path?this=true&that=false#end"))
        }
    }

    Benchmark("HTTP:URI:Decode:PathOnly", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test/this/path"))
        }
    }

    Benchmark("HTTP:URI:Decode:FullURL", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("https://example.com:8080/test/path?query=value#fragment"))
        }
    }

    Benchmark("HTTP:URI:Decode:LongPath", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/api/v1/users/12345/posts/67890/comments/11111/replies"))
        }
    }

    // MARK: - URI Property Access Benchmarks

    Benchmark("HTTP:URI:QueryParameters", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test?this=true&that=false&percent=%45this%48").queryParameters)
        }
    }

    Benchmark("HTTP:URI:QueryParameters:Many", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test?a=1&b=2&c=3&d=4&e=5&f=6&g=7&h=8&i=9&j=10").queryParameters)
        }
    }

    Benchmark("HTTP:URI:QueryParameters:NoPercentEncoding", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(URI("/test?this=true&that=false&other=value").queryParameters)
        }
    }

    Benchmark("HTTP:URI:Path:Access", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let uri = URI("/test/this/path?query=value")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(uri.path)
        }
    }

    Benchmark("HTTP:URI:Query:Access", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let uri = URI("/test?this=true&that=false")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(uri.query)
        }
    }

    Benchmark("HTTP:URI:Host:Access", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let uri = URI("https://example.com:8080/test/path")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(uri.host)
        }
    }

    Benchmark("HTTP:URI:Scheme:Access", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let uri = URI("https://example.com/test")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(uri.scheme)
        }
    }

    Benchmark("HTTP:URI:Port:Access", configuration: .init(scalingFactor: .kilo)) { benchmark in
        let uri = URI("https://example.com:8080/test")
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            blackHole(uri.port)
        }
    }

    // MARK: - Cookie Benchmarks

    Benchmark("HTTP:Cookie:Decode", configuration: .init(scalingFactor: .kilo)) { benchmark in
        benchmark.startMeasurement()
        for _ in benchmark.scaledIterations {
            let cookies = Cookies(from: ["name=value; name2=value2; name3=value3"])
            blackHole(cookies["name"])
        }
    }
}
