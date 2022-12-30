test_%: src/%*.v tests/tst_%*.v tests/sim_%*.cpp #verilate
	@echo "-- BUILD -------------------"
	verilator -cc --exe --build -j -Os -Wall -DTEST --trace -Itests -I"../RISCV/src" -Isrc --coverage --assert tests/tst_$*.v tests/sim_$*.cpp

	@echo "-- RUN ---------------------"
	obj_dir/Vtst_$*

	@echo "-- COVERAGE ----------------"
	verilator_coverage --annotate logs/annotated logs/coverage.dat

show_%: src/*.v
	yosys -p 'hierarchy -top $*; proc; opt; show -colors 42 -stretch $*' src/$*.v

clean:
	-rm -rf obj_dir logs *.log *.dmp *.vpd coverage.dat core *.asc *.rpt

.PHONY: all prog clean
