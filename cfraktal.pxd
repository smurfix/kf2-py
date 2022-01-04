from libcpp.string cimport string
from libcpp cimport bool
from libcpp.vector cimport vector
from gmpy2 cimport mpfr_t

cdef extern from "<glad/glad.h>":
    struct GLint

cdef extern from "<glm/glm.hpp>":
    struct dvec2 "glm::dvec2"
    struct dmat2 "glm::dmat2"

cdef extern from "<stdint.h>":
    ctypedef unsigned long uint64_t
    ctypedef unsigned short uint32_t
    ctypedef long int64_t
    ctypedef short int32_t
    ctypedef unsigned char uint8_t
    ctypedef char int8_t
    cdef enum BOOL:
        FALSE
        TRUE

cdef extern from "defs.h":
    string version

cdef extern from "matrix.h":
    ctypedef dvec2 vec2
    ctypedef dmat2 mat2

    cppclass polar2:
        double sign
        double scale
        double rotate
        double stretch_factor
        double stretch_angle

        polar2(double g, double s, double r, double sf, double sa)
        polar2()

cdef extern from "floatexp.h":
    struct floatexp
    struct floatexpf

cdef extern from "CDecNumber.h":
    cdef cppclass _bkend:
        mpfr_t data()

    cdef cppclass decNumber:
        _bkend backend()

    cdef cppclass CDecNumber:
        decNumber m_dec

        CDecNumber()
        CDecNumber(const CDecNumber &a)
        CDecNumber(const decNumber &a)
        CDecNumber(const char *a)
        CDecNumber(const string &a)
        CDecNumber(double a)
        CDecNumber(int a)
        CDecNumber operator-(const CDecNumber &a)
        CDecNumber operator+(const CDecNumber &a, const CDecNumber &b)
        CDecNumber operator-(const CDecNumber &a, const CDecNumber &b)
        CDecNumber operator*(const CDecNumber &a, const CDecNumber &b)
        CDecNumber operator/(const CDecNumber &a, const CDecNumber &b)
        CDecNumber operator^(const CDecNumber &a, int b)
        CDecNumber operator=(const mpfr_t &a)

        bool operator>(const CDecNumber &a, int b)
        bool operator<(const CDecNumber &a, int b)
        bool operator==(const CDecNumber &a, int b)
        bool operator<(const CDecNumber &a, const CDecNumber &b)

        CDecNumber sqrt(const CDecNumber &a)

        string ToText()
        int ToInt()

    CDecNumber operator-(const CDecNumber &a)
    CDecNumber operator+(const CDecNumber &a, const CDecNumber &b)
    CDecNumber operator+(const CDecNumber &a, double b)
    CDecNumber operator-(const CDecNumber &a, const CDecNumber &b)
    CDecNumber operator*(const CDecNumber &a, const CDecNumber &b)
    CDecNumber operator*(const double &a, const CDecNumber &b)
    CDecNumber operator*(const CDecNumber &b, const double &a)
    CDecNumber operator*(const int &a, const CDecNumber &b)
    CDecNumber operator*(const CDecNumber &b, const int &a)
    CDecNumber operator/(const CDecNumber &a, const CDecNumber &b)
    CDecNumber operator^(const CDecNumber &a, int b)
    bool operator>(const CDecNumber &a, int b)
    bool operator<(const CDecNumber &a, int b)
    bool operator==(const CDecNumber &a, int b)
    bool operator<(const CDecNumber &a, int b)
    bool operator==(const CDecNumber &a, int b)
    bool operator<(const CDecNumber &a, const CDecNumber &b)
    CDecNumber sqrt(const CDecNumber &a)
    CDecNumber abs(const CDecNumber &a)
    CDecNumber log(const CDecNumber &a)
    CDecNumber exp(const CDecNumber &a)
    CDecNumber sqr(const CDecNumber &a)

cdef extern from "fraktal_sft.h":
    cdef struct COLOR14:
        unsigned char r
        unsigned char g
        unsigned char b

    cdef struct BITMAPINFOHEADER:
        int64_t biWidth;
        int64_t biHeight;
        uint32_t biBitCount;
        uint64_t biSizeImage;

cdef extern from "CFixedFloat.h":
    cpdef enum SmoothMethod "SmoothMethod":
        SmoothMethod_Log = 0
        SmoothMethod_Sqrt = 1

    cpdef enum BailoutRadiusPreset "BailoutRadiusPreset":
        BailoutRadius_High = 0
        BailoutRadius_2 = 1
        BailoutRadius_Low = 2
        BailoutRadius_Custom = 3

    cpdef enum BailoutNormPreset "BailoutNormPreset":
        BailoutNorm_1 = 0
        BailoutNorm_2 = 1
        BailoutNorm_Infinity = 2
        BailoutNorm_Custom = 3

    cpdef enum ColorMethod "ColorMethod":
        ColorMethod_Standard = 0
        ColorMethod_SquareRoot = 1
        ColorMethod_CubicRoot = 2
        ColorMethod_Logarithm = 3
        ColorMethod_Stretched = 4
        ColorMethod_DistanceLinear = 5
        ColorMethod_DEPlusStandard = 6
        ColorMethod_DistanceLog = 7
        ColorMethod_DistanceSqrt = 8
        ColorMethod_LogLog = 9
        ColorMethod_ATan = 10
        ColorMethod_FourthRoot = 11

    cpdef enum Differences "Differences":
        Differences_Traditional = 0
        Differences_Forward3x3 = 1
        Differences_Central3x3 = 2
        Differences_Diagonal2x2 = 3
        Differences_LeastSquares2x2 = 4
        Differences_LeastSquares3x3 = 5
        Differences_Laplacian3x3 = 6
        Differences_Analytic = 7

    cpdef enum Guess "Guess":
        Guess_No = 0
        Guess_Interior = 1
        Guess_Glitch = 2

    cpdef enum SeriesType "SeriesType":
        SeriesType_None = 0
        SeriesType_Complex = 1
        SeriesType_Real = 2

cdef extern from "CFixedFloat.h":
    struct TextureParams:
        bool m_bTexture
        string m_szTexture
        double m_nImgPower
        int m_nX
        int m_nY
        bool m_bTextureResize

    ctypedef decNumber FixedFloat
    cdef cppclass CFixedFloat:
        FixedFloat m_f;
        CFixedFloat()
        CFixedFloat(CFixedFloat &a)
        CFixedFloat(const mpfr_t &a)
        CFixedFloat(FixedFloat &a)
        CFixedFloat(char *sz)
        CFixedFloat(string &sz)
        CFixedFloat(int a)
        CFixedFloat(double a)
        CFixedFloat(floatexp)
        CFixedFloat(floatexpf)

        string ToText()
        int toInt()
        double ToDouble(int nScaling)
        long double ToLongDouble(int nScaling)
        CFixedFloat Add(CFixedFloat &A)
        CFixedFloat Subtract(CFixedFloat &A)
        CFixedFloat Multiply(CFixedFloat &A)
        CFixedFloat Square()
        CFixedFloat Divide(CFixedFloat &A)
        CFixedFloat &Double()
        CFixedFloat &AbsAdd(CFixedFloat &a, CFixedFloat &b)
        CFixedFloat &Abs()
        bool operator>(CFixedFloat &A)
        bool operator<(CFixedFloat &A)
        bool operator==(CFixedFloat &A)
        CFixedFloat &operator=(CFixedFloat &A)
        CFixedFloat &operator=(string &sz)
        CFixedFloat &operator=(char *sz)
        CFixedFloat &operator=(int a)
        CFixedFloat &operator=(double a)
        CFixedFloat operator/(CFixedFloat &A)
        CFixedFloat operator+(CFixedFloat &A)
        CFixedFloat operator-(CFixedFloat &A)
        CFixedFloat operator-()
        # CFixedFloat &operator*=(CFixedFloat &A)
        # CFixedFloat &operator/=(CFixedFloat &A)
        # CFixedFloat &operator+=(CFixedFloat &A)
        # CFixedFloat &operator-=(CFixedFloat &A)
        # CFixedFloat &operator*=(int A)
        # CFixedFloat &operator/=(int A)
        # CFixedFloat &operator+=(int A)
        # CFixedFloat &operator-=(int A)
        # CFixedFloat &operator*=(double A)
        # CFixedFloat &operator/=(double A)
        # CFixedFloat &operator+=(double A)
        # CFixedFloat &operator-=(double A)

    CFixedFloat abs(const CFixedFloat &A)
    CFixedFloat min(const CFixedFloat &A, const CFixedFloat &B)
    CFixedFloat max(const CFixedFloat &A, const CFixedFloat &B)
    bool operator==(const CFixedFloat &A,int nB)
    bool operator==(int nB,const CFixedFloat &A)
    bool operator>(const CFixedFloat &A,int nB)
    bool operator>(int nB,const CFixedFloat &A)
    bool operator>(const CFixedFloat &A,double nB)
    bool operator>(double nB,const CFixedFloat &A)
    bool operator<(const CFixedFloat &A,int nB)
    bool operator<(int nB,const CFixedFloat &A)
    bool operator<(const CFixedFloat &A,double nB)
    bool operator<(double nB,const CFixedFloat &A)
    CFixedFloat operator*(const CFixedFloat &A,long nB)
    CFixedFloat operator*(long nB,const CFixedFloat &A)
    CFixedFloat operator*(const CFixedFloat &A,int nB)
    CFixedFloat operator*(int nB,const CFixedFloat &A)
    CFixedFloat operator*(const CFixedFloat &A,double nB)
    CFixedFloat operator*(double nB,const CFixedFloat &A)
    CFixedFloat operator/(const CFixedFloat &A,int nB)
    CFixedFloat operator/(int nB,const CFixedFloat &A)
    CFixedFloat operator/(const CFixedFloat &A,double nB)
    CFixedFloat operator/(double nB,const CFixedFloat &A)
    CFixedFloat operator+(const CFixedFloat &A,int nB)
    CFixedFloat operator+(int nB,const CFixedFloat &A)
    CFixedFloat operator+(const CFixedFloat &A,double nB)
    CFixedFloat operator+(double nB,const CFixedFloat &A)
    CFixedFloat operator-(const CFixedFloat &A,int nB)
    CFixedFloat operator-(int nB,const CFixedFloat &A)
    CFixedFloat operator-(const CFixedFloat &A,double nB)
    CFixedFloat operator-(double nB,const CFixedFloat &A)
    CFixedFloat operator^(const CFixedFloat &A,long nB)
    CFixedFloat sqr(const CFixedFloat &A)
    CFixedFloat exp(const CFixedFloat &A)
    CFixedFloat expm1(const CFixedFloat &A)
    CFixedFloat sin(const CFixedFloat &A)
    CFixedFloat cos(const CFixedFloat &A)
    bool isnan(const CFixedFloat &A)
    bool isinf(const CFixedFloat &A)
    


cdef extern from "<half.h>":
    struct half

cdef extern from "exr.h":
    cdef struct EXRChannels:
        bool R
        bool G
        bool B
        bool N
        bool NF
        bool DEX
        bool DEY
        bool T
        bool Preview

cdef extern from "reference.h":
    cpdef enum Reference_Type "Reference_Type":
        Reference_Float = 0
        Reference_Double = 1
        Reference_LongDouble = 2
        Reference_ScaledFloat = 3
        Reference_ScaledDouble = 4
        Reference_FloatExpFloat = 5
        Reference_FloatExpDouble = 6

cdef extern from "opengl.h":
    struct response_init_t:
        bool success
        int major
        int minor
        string message

    struct request_compile_t:
        string fragment_src

    struct response_compile_t:
        bool success
        string vertex_log
        string fragment_log
        string link_log

    struct request_configure_t:
        int64_t jitter_seed
        int jitter_shape
        double jitter_scale
        bool show_glitches
        bool inverse_transition
        int64_t iterations
        int64_t iterations_min
        int64_t iterations_max
        double iter_div
        double color_offset
        ColorMethod color_method
        Differences differences
        double color_phase_strength
        vector[unsigned char] colors # multiple of 3
        unsigned char interior_color[3]
        bool smooth
        bool flat
        # infinite waves
        bool multiwaves_enabled
        bool multiwaves_blend
        vector[GLint] multiwaves # multiple of 3
        # slopes
        bool slopes
        double slope_power
        double slope_ratio
        double slope_angle
        # image texture
        bool texture_enabled
        double texture_merge
        double texture_power
        double texture_ratio
        int64_t texture_width
        int64_t texture_height
        unsigned char *texture
        bool use_srgb
        double zoom_log2

    struct request_render_t:
        int64_t width
        int64_t height
        uint32_t *n_msb
        uint32_t *n_lsb
        float *n_f
        float *t
        float *dex
        float *dey
        half *rgb16
        unsigned char *rgb8


cdef extern from "reference.h":
    cdef struct Reference
    Reference *reference_new(int64_t, bool, Reference_Type)
    void reference_delete(Reference *)
    void reference_append(Reference *, const floatexp &X, const floatexp &Y, const floatexp &Z)
    Reference_Type reference_type(Reference *)


#cdef extern from "main_numbertype.h":
cpdef enum NumberType_Bit:
    NumberType_Single         = 0
    NumberType_Double         = 1
    NumberType_LongDouble     = 2
    NumberType_Quad           = 3
    NumberType_FloatExpSingle = 4
    NumberType_FloatExpDouble = 5
    NumberType_RescaledSingle = 6
    NumberType_RescaledDouble = 7

cdef extern from "main_numbertype.h":
    cdef struct NumberType:
        bool Single
        bool Double
        bool LongDouble
        bool Quad
        bool FloatExpSingle
        bool FloatExpDouble
        bool RescaledSingle
        bool RescaledDouble

cdef extern from "Settings.h":
    cdef cppclass Settings:
        Settings()

cdef extern from "fraktal_sft.h":
    struct TH_FIND_CENTER

    cdef cppclass CFraktalSFT:

        CFraktalSFT()

        int m_opengl_major
        int m_opengl_minor
        bool renderRunning()
        bool renderJoin()
        bool GetIsRendering()
        bool m_bInhibitColouring
        bool m_bInteractive
        int nPos
        void MandelCalc(Reference_Type reftype)
        void MandelCalcSIMD()
        # template <typename mantissa> void MandelCalc1()
        # template <typename mantissa, typename exponent> void MandelCalcScaled()
        # void MandelCalcNANOMB1()
        # void MandelCalcNANOMB2()
        void Done()

        void SetPosition(CDecNumber &re, CDecNumber &im, CDecNumber &radius)
        CFixedFloat m_CenterRe
        CFixedFloat m_CenterIm
        CFixedFloat m_ZoomRadius

        string ToZoom()
        void SetImageSize(int nx, int ny)
        void Render(bool noThread, bool resetOldGlitch)
        void CalcStart(int x0, int x1, int y0, int y1)
        # HBITMAP GetBitmap()
        # HBITMAP ShrinkBitmap(HBITMAP bmSrc,int nNewWidth,int nNewHeight,int mode = 1)
        void UpdateBitmap()
        int GetImageWidth() # m_nX
        int GetImageHeight() # m_nY

        uint32_t *m_nPixels_LSB
        uint32_t *m_nPixels_MSB # TODO
        int m_row # stride

        uint8_t *m_lpBits
        BITMAPINFOHEADER *m_bmi;

        void Stop()
        int CountFrames(int nProcent)
        void Zoom(double nZoomSize)
        void Zoom(int nXPos, int nYPos, double nZoomSize, int nWidth, int nHeight, bool bReuseCenter = FALSE, bool autoRender = true)
        bool Center(int &rx, int &ry, bool bSkipM = FALSE, bool bQuick = FALSE)
        double GetProgress(double *reference = nullptr, double *approximation = nullptr, double *good_guessed = nullptr, double *good = nullptr, double *queued = nullptr, double *bad = nullptr, double *bad_guessed = nullptr)
        void ResetTimers()
        void GetTimers(double *total_wall, double *total_cpu = nullptr, double *reference_wall = nullptr, double *reference_cpu = nullptr, double *approximation_wall = nullptr, double *approximation_cpu = nullptr, double *perturbation_wall = nullptr, double *perturbation_cpu = nullptr)
        string GetPosition()
        void GetIterations(int64_t &nMin, int64_t &nMax, int *pnCalculated = NULL, int *pnType = NULL, bool bSkipMaxIter = FALSE)
        int64_t GetIterations()
        void SetIterations(int64_t nIterations)
        void FixIterLimit()
        string GetRe()
        string GetRe(int nXPos, int nYPos, int width, int height)
        string GetIm()
        string GetIm(int nXPos, int nYPos, int width, int height)
        string GetZoom()
        void GenerateColors(int nParts, int nSeed = -1)
        void GenerateColors2(int nParts, int nSeed = -1, int nWaves = 9)
        void AddWave(int nCol, int nPeriod = -1, int nStart = -1)
        void ChangeNumOfColors(int nParts)
        int GetNumOfColors()
        void ApplyColors(int x0, int x1, int y0, int y1)
        void ApplyColors()
        void SetColor(int x, int y, int w, int h)

        void ApplyIterationColors()
        void ApplyPhaseColors()
        void ApplySmoothColors()
        int GetSeed()
        COLOR14 GetKeyColor(int i)
        void SetKeyColor(COLOR14 col, int i)
        COLOR14 GetColor(int i)
        COLOR14 GetInteriorColor()
        void SetInteriorColor(COLOR14 &c)
        void ResetParameters()
        bool OpenFile(string &szFile, bool bNoLocation)
        bool OpenString(string &szText, bool bNoLocation)
        bool OpenMapB(string &szFile, bool bReuseCenter, double nZoomSize)
        bool OpenMapEXR(string &szFile)
        string ToText()
        bool SaveFile(string &szFile, bool overwrite)
        double GetIterDiv()
        void SetIterDiv(double nIterDiv)
        int SaveJpg(string &szFile, int nQuality, int nWidth, int nHeight)
        int64_t GetMaxApproximation()
        int64_t GetIterationOnPoint(int x, int y)
        double GetTransOnPoint(int x, int y)
        bool AddReference(int x, int y, bool bEraseAll = FALSE, bool bNoGlitchDetection = FALSE, bool bResuming = FALSE)
        bool HighestIteration(int &rx, int &ry)
        void IgnoreIsolatedGlitches()
        int FindCenterOfGlitch(int &rx, int &ry)
        void FindCenterOfGlitch(int x0, int x1, int y0, int y1, TH_FIND_CENTER *p)
        int GetColorIndex(int x, int y)
        bool GetFlat()
        void SetFlat(bool bFlat)
        bool GetTransition()
        void SetTransition(bool bTransition)
        bool GetITransition()
        void SetITransition(bool bITransition)

        void SaveMap(string &szFile)
        void SaveMapB(string &szFile)

        SmoothMethod GetSmoothMethod()
        void SetSmoothMethod(int nSmoothMethod)
        BailoutRadiusPreset GetBailoutRadiusPreset()
        void SetBailoutRadiusPreset(int nBailoutRadiusPreset)
        double GetBailoutRadiusCustom()
        void SetBailoutRadiusCustom(double nBailoutRadiusCustom)
        double GetBailoutRadius()
        BailoutNormPreset GetBailoutNormPreset()
        void SetBailoutNormPreset(int nBailoutNormPreset)
        double GetBailoutNormCustom()
        void SetBailoutNormCustom(double nBailoutNormCustom)
        double GetBailoutNorm()
        int GetPower()
        void SetPower(int nPower)
        void SetColorMethod(int nColorMethod)
        ColorMethod GetColorMethod()
        void SetDifferences(int nDifferences)
        Differences GetDifferences()
        void SetColorOffset(int nColorOffset)
        int GetColorOffset()
        void SetPhaseColorStrength(double nPhaseColorStrength)
        double GetPhaseColorStrength()
        void ErasePixel(int x, int y)

        void StoreLocation()
        void Mirror(int x, int y)

        int GetMWCount()
        void SetMW(bool bMW, bool bBlend)
        int GetMW(bool *pbBlend = NULL)
        bool GetMW(int nIndex, int &nPeriod, int &nStart, int &nType)
        bool AddMW(int nPeriod, int nStart, int nType)
        bool UpdateMW(int nIndex, int nPeriod, int nStart, int nType)
        bool DeleteMW(int nIndex)

        int64_t GetMaxExceptCenter()
        void SetFractalType(int nFractalType)
        int GetFractalType()

        int GetExponent()

        bool GetSlopes(int &nSlopePower, int &nSlopeRatio, int &nSlopeAngle)
        void SetSlopes(bool bSlope, int nSlopePower, int nSlopeRatio, int nSlopeAngle)

        bool GetTexture(double &nImgMerge,double &nImgPower,int &nImgRatio,string &szTexture)
        void SetTexture(bool bTexture,double nImgMerge,double nImgPower,int nImgRatio,string &szTexture)

        bool GetTextureResize()
        void SetTextureResize(bool resize)

        void AddInflectionPont(int x, int y)
        void RemoveInflectionPoint()

        int GetOpenCLDeviceIndex()
        void SetOpenCLDeviceIndex(int i)

        void OutputIterationData(int x, int y, int w, int h, bool bGlitch, int64_t antal, double test1, double test2, double phase, double nBailout, double complex &de, int power)
        void OutputPixelData(int x, int y, int w, int h, bool bGlitch)
        Guess GuessPixel(int x, int y, int x0, int y0, int x1, int y1)
        Guess GuessPixel(int x, int y, int w, int h)

        bool OpenSettings(string &filename)
        bool SaveSettings(string &filename, bool overwrite)

        void SetTransformPolar(polar2 &P)
        polar2 GetTransformPolar()
        void SetTransformMatrix(mat2 &M)
        mat2 GetTransformMatrix()

        # Settings

        double GetZoomSize()
        void   SetZoomSize(double z)

        int64_t    GetMaxReferences()
        void   SetMaxReferences(int64_t r)

        double GetGlitchLowTolerance()
        void   SetGlitchLowTolerance(double b)

        double GetApproxLowTolerance()
        void   SetApproxLowTolerance(double b)

        bool   GetAutoApproxTerms()
        void   SetAutoApproxTerms(bool b)

        int64_t    GetApproxTerms()
        void   SetApproxTerms(int64_t t)

        int64_t    GetWindowWidth()
        void   SetWindowWidth(int64_t w)

        int64_t    GetWindowHeight()
        void   SetWindowHeight(int64_t h)

        int64_t    GetWindowTop()
        void   SetWindowTop(int64_t w)

        int64_t    GetWindowLeft()
        void   SetWindowLeft(int64_t w)

        int64_t    GetWindowBottom()
        void   SetWindowBottom(int64_t w)

        int64_t    GetWindowRight()
        void   SetWindowRight(int64_t w)

        double GetThreadsPerCore()
        void   SetThreadsPerCore(double t)

        int64_t    GetThreadsReserveCore()
        void   SetThreadsReserveCore(int64_t t)

        bool   GetAnimateZoom()
        void   SetAnimateZoom(bool b)

        bool   GetArbitrarySize()
        void   SetArbitrarySize(bool b)

        bool   GetReuseReference()
        void   SetReuseReference(bool b)

        bool   GetAutoSolveGlitches()
        void   SetAutoSolveGlitches(bool b)

        bool   GetGuessing()
        void   SetGuessing(bool b)

        bool   GetSolveGlitchNear()
        void   SetSolveGlitchNear(bool b)

        bool   GetNoApprox()
        void   SetNoApprox(bool b)

        bool   GetMirror()
        void   SetMirror(bool b)

        bool   GetAutoIterations()
        void   SetAutoIterations(bool b)

        bool   GetShowGlitches()
        void   SetShowGlitches(bool b)

        bool   GetNoReuseCenter()
        void   SetNoReuseCenter(bool b)

        int64_t    GetIsolatedGlitchNeighbourhood()
        void   SetIsolatedGlitchNeighbourhood(int64_t n)

        int64_t    GetJitterSeed()
        void   SetJitterSeed(int64_t n)

        int64_t    GetJitterShape()
        void   SetJitterShape(int64_t n)

        double GetJitterScale()
        void   SetJitterScale(double n)

        bool   GetDerivatives()
        void   SetDerivatives(bool b)

        bool   GetShowCrossHair()
        void   SetShowCrossHair(bool b)

        bool   GetUseNanoMB1()
        void   SetUseNanoMB1(bool b)

        bool   GetUseNanoMB2()
        void   SetUseNanoMB2(bool b)

        int64_t    GetOrderM()
        void   SetOrderM(int64_t t)

        int64_t    GetOrderN()
        void   SetOrderN(int64_t t)

        bool   GetInteriorChecking()
        void   SetInteriorChecking(bool b)

        double GetRadiusScale()
        void   SetRadiusScale(double b)

        int64_t    GetShrink()
        void   SetShrink(int64_t n)

        bool   GetHalfColour()
        void   SetHalfColour(bool b)

        bool   GetSaveOverwrites()
        void   SetSaveOverwrites(bool b)

        bool   GetThreadedReference()
        void   SetThreadedReference(bool b)

        int64_t    GetSIMDChunkSize()
        void   SetSIMDChunkSize(int64_t n)

        int64_t    GetSIMDVectorSize()
        void   SetSIMDVectorSize(int64_t n)

        int64_t GetGlitchCenterMethod()
        void    SetGlitchCenterMethod(int64_t b)
        bool    GetUseArgMinAbsZAsGlitchCenter()

        bool   GetUseOpenCL()
        void   SetUseOpenCL(bool b)

        int64_t GetOpenCLPlatform()
        void    SetOpenCLPlatform(int64_t n)

        bool   GetOpenCLThreaded()
        void   SetOpenCLThreaded(bool b)

        EXRChannels GetEXRChannels()
        void SetEXRChannels(EXRChannels n)

        bool   GetEXRParallel()
        void   SetEXRParallel(bool b)

        bool   GetSaveNewtonProgress()
        void   SetSaveNewtonProgress(bool b)

        bool   GetExponentialMap()
        void   SetExponentialMap(bool b)

        bool   GetDerivativeGlitch()
        void   SetDerivativeGlitch(bool b)

        bool   GetReferenceStrictZero()
        void   SetReferenceStrictZero(bool b)

        NumberType GetNumberTypes()
        void SetNumberTypes(NumberType n)

        void   GetTargetDimensions(int64_t *w, int64_t *h, int64_t *s)
        void   SetTargetDimensions(int64_t w, int64_t h, int64_t s)

