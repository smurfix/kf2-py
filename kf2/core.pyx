from cfraktal cimport CFraktalSFT, version
from cfraktal cimport uint8_t, uint32_t, int32_t, int64_t, uint64_t, bool, string, Reference_Type, CDecNumber
from cfraktal cimport Differences_Analytic
from gmpy2 cimport mpfr, MPFR_Check, MPFR, mpfr_t, import_gmpy2, GMPy_MPFR_From_mpfr
cimport numpy as np
cimport cython
from cython cimport view

import numpy
import cairo
import pathlib
import PIL
import PIL.Image
import PIL.ImageOps
import sys


cdef extern from "mpfr.h":
    void mpfr_free_cache2(int)
    int MPFR_FREE_LOCAL_CACHE

import_gmpy2()
np.import_array()

cdef int32_t UNEVALUATED = 0x80000000

def flush_mp_cache():
    mpfr_free_cache2(MPFR_FREE_LOCAL_CACHE)

levels = {
    "debug":0,
    "status":1,
    "info":2,
    "warn":3,
    "error":4,
}

def fnfix(fn):
    if isinstance(fn,pathlib.PurePath):
        fn = str(fn)
    if isinstance(fn,str):
        fn = fn.encode("utf-8")
    return fn

cdef class Fraktal:
    cdef CFraktalSFT* cfr  # Hold a C++ instance which we're wrapping

# Logging

    cdef int _log_level
    @property
    def log_level(self):
        return self._log_level
    @log_level.setter
    def log_level(self, value):
        if isinstance(value,str):
            value = levels[value]
        self._log_level = value

    @property
    def log_levels(self):
        return levels
    def is_logging(self, level) -> bool:
        """True if we're logging at this level"""
        if isinstance(level,str):
            level = levels[level]
        return level >= self.log_level

    def log(self, level, msg, *args):
        """Log a message if the log level is set"""
        if isinstance(level,str):
            level = levels[level]
        if level >= self.log_level:
            if args:
                msg = msg % args
            print(msg, file=sys.stderr if level >= levels["status"] else sys.stdout)

    def __cinit__(self):
        self.cfr = new CFraktalSFT()
        self._log_level = levels["warn"]

    def renderFractal(self):
        """Render an image"""
        with nogil:
            self.cfr.RenderFractal()

    @property
    def stop_render(self):
        return self.cfr.m_bStop
    @stop_render.setter
    def stop_render(self, value:bool):
        self.cfr.m_bStop = value

    @property
    def nX(self):
        return self.cfr.GetImageWidth()

    @property
    def nY(self):
        return self.cfr.GetImageHeight()

    @property
    def iter_data(self):
        """
        Return the iter counts as a numpy array.

        TODO this ignores MSB.
        """
        return np.PyArray_SimpleNewFromData(2,[self.nY,self.nX], np.NPY_UINT32, self.cfr.m_nPixels_LSB).T

    def _check_bitmap(self):
        if not self.cfr.m_bmi:
            raise RuntimeError("need to allocate bitmap")
        if self.cfr.m_bmi.biBitCount != 32:
            raise RuntimeError("need 32-bit bitmap")

    @property
    def image_data(self):
        """
        Return the image as a numpy array.

        TODO this returns RGB[A] as a single integer.
        """
        self._check_bitmap()
        return np.PyArray_SimpleNewFromData(2,[self.cfr.m_bmi.biHeight,self.cfr.m_bmi.biWidth], np.NPY_UINT32, self.cfr.m_lpBits).T

    @property
    def image_data_rgba(self):
        """
        Return the image as a numpy array with separate RGBA components.

        TODO this returns RGB[A] as a single integer.
        """
        self._check_bitmap()
        return np.PyArray_SimpleNewFromData(3,[self.cfr.m_bmi.biHeight,self.cfr.m_bmi.biWidth,4], np.NPY_UINT8, self.cfr.m_lpBits)

    @property
    def image_bytes(self):
        """
        Return the image as a linear array of bytes.
        """
        self._check_bitmap()
        return np.PyArray_SimpleNewFromData(1,[4*self.cfr.m_bmi.biHeight*self.cfr.m_bmi.biWidth], np.NPY_UINT8, self.cfr.m_lpBits)

    @property
    def opengl_major(self):
        return self.cfr.m_opengl_major
    @property
    def opengl_minor(self):
        return self.cfr.m_opengl_minor

    @property
    def inhibit_colouring(self):
        return self.cfr.m_bInhibitColouring
    @inhibit_colouring.setter
    def inhibit_colouring(self, flag:bool):
        self.cfr.m_bInhibitColouring = flag

    @property
    def interactive(self):
        return self.cfr.m_bInteractive
    @interactive.setter
    def interactive(self, flag:bool):
        self.cfr.m_bInteractive = flag

    def mandelCalc(self, reftype: Reference_Type):
        self.cfr.MandelCalc(reftype)

    def mandelCalcSIMD(self):
        self.cfr.MandelCalcSIMD()
    # # template <typename mantissa> void MandelCalc1()
    # # template <typename mantissa, typename exponent> void MandelCalcScaled()
    # # void MandelCalcNANOMB1()
    # # void MandelCalcNANOMB2()
    def Done(self):
        self.cfr.Done()

    cdef cf_SetPosition(self, mpfr_t x,mpfr_t y,mpfr_t z):
        cdef CDecNumber cx=x
        cdef CDecNumber cy=y
        cdef CDecNumber cz=z
        self.cfr.SetPosition(cx,cy,cz)

    def setPosition(self, x,y,z):
        """
        Set the position to render.
        X,Y: coordinates of the image center.
        Z: zoom factor
        nx, ny: size of the rectangle to be rendered

        Input is either multiprecision floats or strings.
        If the latter, Z is the zoom factor. radius := 2/z.
        """
        self.not_rendering()
        if isinstance(x,str):
            x = mpfr(x)
            y = mpfr(y)
            z = 2/mpfr(z)
        elif not MPFR_Check(x):
            raise RuntimeError("Either MPFR or string arguments")
        self.cf_SetPosition(MPFR(x), MPFR(y), MPFR(z))

    def toZoom(self):
        return self.cfr.ToZoom()

    def getImageSize(self):
        """
        Retrieve current image size.
        """
        return (self.nX,self.nY)

    def setImageSize(self, nx:int, ny:int):
        """
        Change image size.
        """
        self.not_rendering()
        cdef int x = nx
        cdef int y = ny

        with nogil:
            self.cfr.SetImageSize(x,y)

    # void CalcStart(int x0, int x1, int y0, int y1)
    # HBITMAP GetBitmap()
    # HBITMAP ShrinkBitmap(HBITMAP bmSrc,int nNewWidth,int nNewHeight,int mode = 1)
    # void UpdateBitmap()

    # int CountFrames(int nProcent)
    # void Zoom(double nZoomSize)
    # void Zoom(int nXPos, int nYPos, double nZoomSize, int nWidth, int nHeight, bool bReuseCenter = FALSE, bool autoRender = true)
    # bool Center(int &rx, int &ry, bool bSkipM = FALSE, bool bQuick = FALSE)
    # double GetProgress(double *reference = nullptr, double *approximation = nullptr, double *good_guessed = nullptr, double *good = nullptr, double *queued = nullptr, double *bad = nullptr, double *bad_guessed = nullptr)
    def resetTimers(self):
        self.cfr.ResetTimers()

    # void GetTimers(double *total_wall, double *total_cpu = nullptr, double *reference_wall = nullptr, double *reference_cpu = nullptr, double *approximation_wall = nullptr, double *approximation_cpu = nullptr, double *perturbation_wall = nullptr, double *perturbation_cpu = nullptr)
    # string GetPosition()

    # void GetIterations(int64_t &nMin, int64_t &nMax, int *pnCalculated = NULL, int *pnType = NULL, bool bSkipMaxIter = FALSE)
    @property
    def iter_limits(self):
        cdef int64_t n_min = 0
        cdef int64_t n_max = 0
        self.cfr.GetIterations(n_min,n_max)
        return n_min,n_max

    # int64_t GetIterations()
    # void SetIterations(int64_t nIterations)
    @property
    def iterations(self):
        return self.cfr.GetIterations()
    @iterations.setter
    def iterations(self, lim: int):
        self.cfr.SetIterations(lim)

    # void FixIterLimit()
    def fixIterLimit(self):
        """updates the iter limit"""
        with nogil:
            self.cfr.FixIterLimit()


    # string GetRe()
    # string GetRe(int nXPos, int nYPos, int width, int height)
    # string GetIm()
    # string GetIm(int nXPos, int nYPos, int width, int height)
    # string GetZoom()
    # void GenerateColors(int nParts, int nSeed = -1)
    # void GenerateColors2(int nParts, int nSeed = -1, int nWaves = 9)
    # void AddWave(int nCol, int nPeriod = -1, int nStart = -1)
    # void ChangeNumOfColors(int nParts)
    # int GetNumOfColors()
    def applyColors(self):
        """ Calculate m_cPos, run OpenGL / CPU coloring"""
        self.cfr.ApplyColors()
    def setColor(self, x:int, y:int, w:int=1, h:int=1):
        """ CPU coloring of a single pixel"""
        self.cfr.SetColor(x,y,w,h)
    def applyColorRange(self, x0:int, x1:int, y0:int, y1:int):
        """ CPU coloring of a single range, one 16x16 square at a time"""
        self.cfr.ApplyColors(x0,x1,y0,y1)

    # void ApplyIterationColors()
    # void ApplyPhaseColors()
    # void ApplySmoothColors()
    # int GetSeed()
    # COLOR14 GetKeyColor(int i)
    # void SetKeyColor(COLOR14 col, int i)
    # COLOR14 GetColor(int i)
    # COLOR14 GetInteriorColor()
    # void SetInteriorColor(COLOR14 &c)
    # void ResetParameters()
    # bool OpenFile(string &szFile, bool bNoLocation = FALSE)
    # bool OpenString(string &szText, bool bNoLocation = FALSE)

    def openFile(self, filename:str, noLocation:bool=False):
        if not self.cfr.OpenFile(fnfix(filename), noLocation):
            raise RuntimeError("Could not open %s" % (repr(filename)))
        if self.cfr.GetDifferences() == Differences_Analytic and not self.derivatives:
            self.log("warn","automatically enabling derivatives for analytic DE")
            self.derivatives = True

    def openMapB(self, filename:str, reuseCenter:bool=False, zoomSize:float=1):
        if not self.cfr.OpenMapB(fnfix(filename), reuseCenter, zoomSize):
            raise RuntimeError("Could not open %s" % (repr(filename)))

    def openMapEXR(self, filename:str):
        if not self.cfr.OpenMapEXR(fnfix(filename)):
            raise RuntimeError("Could not open %s" % (repr(filename)))

    def openMap(self, filename:str):
        if not self.cfr.OpenMapB(fnfix(filename), False,1):
            self.OpenMapEXR(filename)

    # bool OpenMapEXR(string &szFile)
    # string ToText()
    # bool SaveFile(string &szFile, bool overwrite)
    # double GetIterDiv()
    # void SetIterDiv(double nIterDiv)

    @cython.boundscheck(False)
    @cython.wraparound(False)
    def saveEXR(self, filename:str):
        cdef uint8_t[:,:,::1] img = self.image_data_rgba
        cdef np.ndarray[np.uint8_t, ndim=3, mode='c'] rgb = numpy.empty((self.nY,self.nX,3), numpy.ubyte, 'C')
        cdef uint32_t x,y,xx,yy

        if not self.cfr.GetHalfColour():
            self.cfr.SetHalfColour(True)
            self.cfr.ApplyColors()

        yy=self.nY
        xx=self.nX
        for y in range(yy):
            for x in range(xx):
                rgb[y][x][0] = img[y][x][2]
                rgb[y][x][1] = img[y][x][1]
                rgb[y][x][2] = img[y][x][0]

        cdef string cmt
        cdef np.uint8_t* rgbd = &rgb[0,0,0]
        self.cfr.SaveEXR(fnfix(filename),rgbd, self.nX,self.nY,cmt,1)

    def saveKFR(self, filename:str):
        self.cfr.SaveFile(fnfix(filename), True)
    def saveMap(self, filename:str):
        self.cfr.SaveMapB(fnfix(filename))

    @property
    def pilImage(self):
        img = cairo.ImageSurface.create_for_data(self.image_bytes, cairo.FORMAT_RGB24, self.image_width, self.image_height)

        cairoFormat = img.get_format()
        if cairoFormat == cairo.FORMAT_ARGB32 or cairoFormat == cairo.FORMAT_RGB24:
            # Cairo has ARGB. Convert this to RGB for PIL which supports only RGB or RGBA.
            pilMode = 'RGB'
            argbArray = self.image_bytes.reshape( -1, 4 )
            rgbArray = argbArray[ :, 2::-1 ]
            pilData = rgbArray.reshape( -1 )
        else:
            raise ValueError( 'Unsupported cairo format: %d' % cairoFormat )
        pilImage = PIL.Image.frombuffer(pilMode,
                ( img.get_width(), img.get_height() ), pilData, "raw",
                pilMode, 0, 1 )
        pilImage = pilImage.convert( 'RGB' )
        pilImage = PIL.ImageOps.flip(pilImage)
        return pilImage

    # int64_t GetMaxApproximation()
    # int64_t GetIterationOnPoint(int x, int y)
    # double GetTransOnPoint(int x, int y)

    # bool AddReference(int x, int y, bool bEraseAll = FALSE, bool bResuming = FALSE)
    def addReference(self, x:int, y:int, eraseAll:bool=False, resuming:bool=False):
        """Sets the reference r+i values to these coordinates"""
        cdef int xx = x
        cdef int yy = y
        cdef bool ea = eraseAll
        cdef bool re = resuming
        cdef bool res;
        with nogil:
            res = self.cfr.AddReference(xx,yy, ea,re)
        return res

    @property
    def add_references(self):
        return self.cfr.m_bAddReference
    @add_references.setter
    def add_references(self, num:int):
        self.cfr.m_bAddReference = num


    # bool HighestIteration(int &rx, int &ry)
    # void IgnoreIsolatedGlitches()

    # int FindCenterOfGlitch(int &rx, int &ry)
    def findCenterOfGlitch(self):
        """
        Finds the "best" glitch center.
        Returns a (x,y,size) tuple, or None if no glitch found.
        """
        cdef int x=0 # init silences cython warning
        cdef int y=0
        cdef int r
        with nogil:
            r = self.cfr.FindCenterOfGlitch(x,y)
        if r == 0:
            return None
        return (x,y,r)

    # void FindCenterOfGlitch(int x0, int x1, int y0, int y1, TH_FIND_CENTER *p)
    # int GetColorIndex(int x, int y)
    # bool GetFlat()
    # void SetFlat(bool bFlat)
    # bool GetTransition()
    # void SetTransition(bool bTransition)
    # bool GetITransition()
    # void SetITransition(bool bITransition)

    # void SaveMap(string &szFile)
    # void SaveMapB(string &szFile)

    # SmoothMethod GetSmoothMethod()
    # void SetSmoothMethod(int nSmoothMethod)
    # BailoutRadiusPreset GetBailoutRadiusPreset()
    # void SetBailoutRadiusPreset(int nBailoutRadiusPreset)
    # double GetBailoutRadiusCustom()
    # void SetBailoutRadiusCustom(double nBailoutRadiusCustom)
    # double GetBailoutRadius()
    # BailoutNormPreset GetBailoutNormPreset()
    # void SetBailoutNormPreset(int nBailoutNormPreset)
    # double GetBailoutNormCustom()
    # void SetBailoutNormCustom(double nBailoutNormCustom)
    # double GetBailoutNorm()
    # int GetPower()
    # void SetPower(int nPower)
    # void SetColorMethod(int nColorMethod)
    # ColorMethod GetColorMethod()
    # void SetDifferences(int nDifferences)
    # Differences GetDifferences()
    # void SetColorOffset(int nColorOffset)
    # int GetColorOffset()
    # void SetPhaseColorStrength(double nPhaseColorStrength)
    # double GetPhaseColorStrength()
    # void ErasePixel(int x, int y)

    # void StoreLocation()
    # void Mirror(int x, int y)

    # int GetMWCount()
    # void SetMW(bool bMW, bool bBlend)
    # int GetMW(bool *pbBlend = NULL)
    # bool GetMW(int nIndex, int &nPeriod, int &nStart, int &nType)
    # bool AddMW(int nPeriod, int nStart, int nType)
    # bool UpdateMW(int nIndex, int nPeriod, int nStart, int nType)
    # bool DeleteMW(int nIndex)

    # int64_t GetMaxExceptCenter()
    # void SetFractalType(int nFractalType)
    # int GetFractalType()

    # int GetExponent()

    # bool GetSlopes(int &nSlopePower, int &nSlopeRatio, int &nSlopeAngle)
    # void SetSlopes(bool bSlope, int nSlopePower, int nSlopeRatio, int nSlopeAngle)

    # bool GetTexture(double &nImgMerge,double &nImgPower,int &nImgRatio,string &szTexture)
    # void SetTexture(bool bTexture,double nImgMerge,double nImgPower,int nImgRatio,string &szTexture)

    # bool GetTextureResize()
    # void SetTextureResize(bool resize)

    # void AddInflectionPont(int x, int y)
    # void RemoveInflectionPoint()

    # int GetOpenCLDeviceIndex()
    # void SetOpenCLDeviceIndex(int i)

    # void OutputIterationData(int x, int y, int w, int h, bool bGlitch, int64_t antal, double test1, double test2, double phase, double nBailout, complex<double> &de, int power)
    # void OutputPixelData(int x, int y, int w, int h, bool bGlitch)
    # Guess GuessPixel(int x, int y, int x0, int y0, int x1, int y1)
    # Guess GuessPixel(int x, int y, int w, int h)

    def openSettings(self, filename:str):
        """
        Read a .kfr (or other saved settings) file
        """
        if not self.cfr.OpenSettings(fnfix(filename)):
            raise RuntimeError("Could not open %s" % (repr(filename)))

    def saveSettings(self, filename:str, overwrite: bool=True):
        """
        Save the current state to a .kfr file
        """
        if not self.cfr.SaveSettings(fnfix(filename), overwrite):
            raise RuntimeError("Could not save %s" % (repr(filename)))

    # void SetTransformPolar(polar2 &P)
    # polar2 GetTransformPolar()
    # void SetTransformMatrix(mat2 &M)
    # mat2 GetTransformMatrix()

    # settings

    cdef mpfr _center_re(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_CenterRe.m_f.backend().data())

    cdef mpfr _center_im(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_CenterIm.m_f.backend().data())

    cdef mpfr _zoom_radius(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_ZoomRadius.m_f.backend().data())
    @property
    def center_re(self):
        return self._center_re()
    @property
    def center_im(self):
        return self._center_im()
    @property
    def zoom_radius(self):
        return self._zoom_radius()

    @property
    def zoom_size(self):
        return self.cfr.GetZoomSize()
    @zoom_size.setter
    def zoom_size(self, value):
        self.cfr.SetZoomSize(value)

    # Zoom(int nXPos, int nYPos, double nZoomSize, BOOL bReuseCenter, bool center_view)
    def zoom(self, xpos, ypos, factor, reuse_center=True, center_view=False):
        cdef int xp = xpos
        cdef int yp = ypos
        cdef double f = factor
        cdef bool rc = reuse_center
        cdef bool cv = center_view
        with nogil:
            self.cfr.Zoom(xp,yp,f,rc,cv)

    @property
    def auto_glitch(self):
        return self.cfr.m_bAutoGlitch
    @auto_glitch.setter
    def auto_glitch(self, value:int):
        self.cfr.m_bAutoGlitch = value

    @property
    def max_references(self):
        return self.cfr.GetMaxReferences()
    @max_references.setter
    def max_references(self, value):
        self.cfr.SetMaxReferences(value)

    cdef mpfr _ref_r(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_rref.m_f.backend().data())
    cdef mpfr _ref_i(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_irefReuse.m_f.backend().data())
    cdef mpfr _ref_rr(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_rref.m_f.backend().data())
    cdef mpfr _ref_ir(self):
        return GMPy_MPFR_From_mpfr(self.cfr.m_irefReuse.m_f.backend().data())
    @property
    def ref_r(self):
        return self._ref_r()
    @property
    def ref_i(self):
        return self._ref_i()
    @property
    def ref_r_reuse(self):
        return self._ref_rr()
    @property
    def ref_i_reuse(self):
        return self._ref_ir()

    @property
    def glitch_low_tolerance(self):
        return self.cfr.GetGlitchLowTolerance()
    @glitch_low_tolerance.setter
    def glitch_low_tolerance(self, value):
        self.cfr.SetGlitchLowTolerance(value)

    @property
    def approx_low_tolerance(self):
        return self.cfr.GetApproxLowTolerance()
    @approx_low_tolerance.setter
    def approx_low_tolerance(self, value):
        self.cfr.SetApproxLowTolerance(value)

    @property
    def auto_approx_terms(self):
        return self.cfr.GetAutoApproxTerms()
    @auto_approx_terms.setter
    def auto_approx_terms(self, value):
        self.cfr.SetAutoApproxTerms(value)

    @property
    def window_width(self):
        return self.cfr.GetWindowWidth()
    @window_width.setter
    def window_width(self, value):
        self.cfr.SetWindowWidth(value)

    @property
    def window_height(self):
        return self.cfr.GetWindowHeight()
    @window_height.setter
    def window_height(self, value):
        self.cfr.SetWindowHeight(value)

    @property
    def window_top(self):
        return self.cfr.GetWindowTop()
    @window_top.setter
    def window_top(self, value):
        self.cfr.SetWindowTop(value)

    @property
    def window_left(self):
        return self.cfr.GetWindowLeft()
    @window_left.setter
    def window_left(self, value):
        self.cfr.SetWindowLeft(value)

    @property
    def window_bottom(self):
        return self.cfr.GetWindowBottom()
    @window_bottom.setter
    def window_bottom(self, value):
        self.cfr.SetWindowBottom(value)

    @property
    def window_right(self):
        return self.cfr.GetWindowRight()
    @window_right.setter
    def window_right(self, value):
        self.cfr.SetWindowRight(value)

    @property
    def image_width(self):
        return self.cfr.GetImageWidth()

    @property
    def image_height(self):
        return self.cfr.GetImageHeight()

    @property
    def threads_per_core(self):
        return self.cfr.GetThreadsPerCore()
    @threads_per_core.setter
    def threads_per_core(self, value):
        self.cfr.SetThreadsPerCore(value)

    @property
    def threads_reserve_core(self):
        return self.cfr.GetThreadsReserveCore()
    @threads_reserve_core.setter
    def threads_reserve_core(self, value):
        self.cfr.SetThreadsReserveCore(value)

    @property
    def animate_zoom(self):
        return self.cfr.GetAnimateZoom()
    @animate_zoom.setter
    def animate_zoom(self, value):
        self.cfr.SetAnimateZoom(value)

    @property
    def arbitrary_size(self):
        return self.cfr.GetArbitrarySize()
    @arbitrary_size.setter
    def arbitrary_size(self, value):
        self.cfr.SetArbitrarySize(value)

    @property
    def reuse_reference(self):
        return self.cfr.GetReuseReference()
    @reuse_reference.setter
    def reuse_reference(self, value):
        self.cfr.SetReuseReference(value)

    @property
    def auto_glitch(self):
        return self.cfr.m_bAutoGlitch
    @auto_glitch.setter
    def auto_glitch(self, value):
        self.cfr.m_bAutoGlitch = value

    def resetGlitches(self):
        return self.cfr.ResetGlitches()
    @property
    def auto_solve_glitches(self):
        return self.cfr.GetAutoSolveGlitches()
    @auto_solve_glitches.setter
    def auto_solve_glitches(self, value):
        self.cfr.SetAutoSolveGlitches(value)

    # TODO export them as a mapping, as soon as the library supports that
    @property
    def settings_str(self):
        return self.cfr.GetSettings().decode("utf-8")
    @settings_str.setter
    def settings_str(self, data):
        if not self.cfr.SetSettings(data.encode("utf-8")):
            raise RuntimeError("Not recognized")

    @property
    def params_str(self):
        return self.cfr.ToText().decode("utf-8")
    @params_str.setter
    def params_str(self, data):
        if not self.cfr.OpenString(data.encode("utf-8"), True):
            raise RuntimeError("Not recognized")

    @property
    def guessing(self):
        return self.cfr.GetGuessing()
    @guessing.setter
    def guessing(self, value):
        self.cfr.SetGuessing(value)

    @property
    def solve_glitch_near(self):
        return self.cfr.GetSolveGlitchNear()
    @solve_glitch_near.setter
    def solve_glitch_near(self, value):
        self.cfr.SetSolveGlitchNear(value)

    @property
    def no_approx(self):
        return self.cfr.GetNoApprox()
    @no_approx.setter
    def no_approx(self, value):
        self.cfr.SetNoApprox(value)

    @property
    def mirror(self):
        return self.cfr.GetMirror()
    @mirror.setter
    def mirror(self, value):
        self.cfr.SetMirror(value)

    @property
    def auto_iterations(self):
        return self.cfr.GetAutoIterations()
    @auto_iterations.setter
    def auto_iterations(self, value):
        self.cfr.SetAutoIterations(value)

    @property
    def show_glitches(self):
        return self.cfr.GetShowGlitches()
    @show_glitches.setter
    def show_glitches(self, value):
        self.cfr.SetShowGlitches(value)

    @property
    def no_reuse_center(self):
        return self.cfr.GetNoReuseCenter()
    @no_reuse_center.setter
    def no_reuse_center(self, value):
        self.cfr.SetNoReuseCenter(value)

    @property
    def isolated_glitch_neighbourhood(self):
        return self.cfr.GetIsolatedGlitchNeighbourhood()
    @isolated_glitch_neighbourhood.setter
    def isolated_glitch_neighbourhood(self, value):
        self.cfr.SetIsolatedGlitchNeighbourhood(value)

    @property
    def jitter_seed(self):
        return self.cfr.GetJitterSeed()
    @jitter_seed.setter
    def jitter_seed(self, value):
        self.cfr.SetJitterSeed(value)

    @property
    def jitter_scale(self):
        return self.cfr.GetJitterScale()
    @jitter_scale.setter
    def jitter_scale(self, value):
        self.cfr.SetJitterScale(value)

    @property
    def derivatives(self):
        return self.cfr.GetDerivatives()
    @derivatives.setter
    def derivatives(self, value):
        self.cfr.SetDerivatives(value)

    @property
    def show_cross_hair(self):
        return self.cfr.GetShowCrossHair()
    @show_cross_hair.setter
    def show_cross_hair(self, value):
        self.cfr.SetShowCrossHair(value)

    @property
    def use_nano_mb1(self):
        return self.cfr.GetUseNanoMB1()
    @use_nano_mb1.setter
    def use_nano_mb1(self, value):
        self.cfr.SetUseNanoMB1(value)

    @property
    def use_nano_mb2(self):
        return self.cfr.GetUseNanoMB2()
    @use_nano_mb2.setter
    def use_nano_mb2(self, value):
        self.cfr.SetUseNanoMB2(value)

    @property
    def interior_checking(self):
        return self.cfr.GetInteriorChecking()
    @interior_checking.setter
    def interior_checking(self, value):
        self.cfr.SetInteriorChecking(value)

    @property
    def radius_scale(self):
        return self.cfr.GetRadiusScale()
    @radius_scale.setter
    def radius_scale(self, value):
        self.cfr.SetRadiusScale(value)

    @property
    def half_colour(self):
        return self.cfr.GetHalfColour()
    @half_colour.setter
    def half_colour(self, value):
        self.cfr.SetHalfColour(value)

    @property
    def save_overwrites(self):
        return self.cfr.GetSaveOverwrites()
    @save_overwrites.setter
    def save_overwrites(self, value):
        self.cfr.SetSaveOverwrites(value)

    @property
    def threaded_reference(self):
        return self.cfr.GetThreadedReference()
    @threaded_reference.setter
    def threaded_reference(self, value):
        self.cfr.SetThreadedReference(value)

    @property
    def glitch_center_method(self):
        return self.cfr.GetGlitchCenterMethod()
    @glitch_center_method.setter
    def glitch_center_method(self, value):
        self.cfr.SetGlitchCenterMethod(value)

    @property
    def use_opencl(self):
        return self.cfr.GetUseOpenCL()
    @use_opencl.setter
    def use_opencl(self, value):
        self.cfr.SetUseOpenCL(value)

    @property
    def opencl_platform(self):
        return self.cfr.GetOpenCLPlatform()
    @opencl_platform.setter
    def opencl_platform(self, value):
        self.cfr.SetOpenCLPlatform(value)

    @property
    def opencl_threaded(self):
        return self.cfr.GetOpenCLThreaded()
    @opencl_threaded.setter
    def opencl_threaded(self, value):
        self.cfr.SetOpenCLThreaded(value)

    @property
    def exr_parallel(self):
        return self.cfr.GetEXRParallel()
    @exr_parallel.setter
    def exr_parallel(self, value):
        self.cfr.SetEXRParallel(value)

    @property
    def save_newton_progress(self):
        return self.cfr.GetSaveNewtonProgress()
    @save_newton_progress.setter
    def save_newton_progress(self, value):
        self.cfr.SetSaveNewtonProgress(value)

    @property
    def exponential_map(self):
        return self.cfr.GetExponentialMap()
    @exponential_map.setter
    def exponential_map(self, value):
        self.cfr.SetExponentialMap(value)

    @property
    def derivative_glitch(self):
        return self.cfr.GetDerivativeGlitch()
    @derivative_glitch.setter
    def derivative_glitch(self, value):
        self.cfr.SetDerivativeGlitch(value)

    @property
    def reference_strict_zero(self):
        return self.cfr.GetReferenceStrictZero()
    @reference_strict_zero.setter
    def reference_strict_zero(self, value):
        self.cfr.SetReferenceStrictZero(value)

    @property
    def target_dimensions(self):
        cdef int64_t x,y,z
        self.cfr.GetTargetDimensions(&x,&y,&z)
        return x,y,z
    @target_dimensions.setter
    def target_dimensions(self, xyz):
        cdef int64_t x,y,z
        x,y,z = xyz
        self.cfr.SetTargetDimensions(x,y,z)

__version__ = str(version,"utf-8")

