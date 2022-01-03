all: ext

ext:	
	python3 setup.py build_ext --inplace
force:
	touch kf2/core.pyx
	$(MAKE) ext
