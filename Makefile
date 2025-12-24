	# cd Benchmarks && ENABLE_HB_BENCHMARKS=true swift package benchmark baseline compare 3172405991470c278a465a0ef0f1c423fd65a610 --format markdown
	# cd Benchmarks && ENABLE_HB_BENCHMARKS=true swift package benchmark baseline compare d8f3ec5875b46a6886e2c272a16dec59cebf78d8 --format markdown

benchmark_compare:
	cd Benchmarks && ENABLE_HB_BENCHMARKS=true swift package benchmark baseline compare e0233e0bc20623d718b250c924f6cc1e09fc147d --format markdown