all: embed ext

embed:
	$(MAKE) -C .. embed
ext:	
	python3 setup.py build_ext --inplace
