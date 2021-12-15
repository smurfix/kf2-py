ORIG_CPP = scale_bitmap.cpp fraktal_sft.cpp
all: ext

ext:	
	@./link.sh ../fraktal_sft/ kf- $(ORIG_CPP)
	python3 setup.py build_ext --inplace
