# ThreeBody3D fresh-environment test

- Date: 2026-07-19 21:04:17 +12:00
- Branch: v0.4-development
- Commit: f682458
- Working tree dirty: false
- Temporary project: C:\Users\ian_g\AppData\Local\Temp\ThreeBody3D-fresh-11d95f8f94f94f5c89717c43984375af
- Elapsed seconds: 20.136
- Overall status: **PASS**

## Scope

The test used a newly created Julia project and verified that a fresh user can:

1. develop and instantiate ThreeBody3D from the repository;
2. load the package;
3. construct a system and Cartesian state;
4. run simulate with the documented :accurate profile;
5. compute a diagnostics_report;
6. construct a trajectory plot with display suppressed.

## Process log

```text
ThreeBody3D fresh-environment test
  Julia version:                 1.12.5
  temporary project:             C:\Users\ian_g\AppData\Local\Temp\ThreeBody3D-fresh-11d95f8f94f94f5c89717c43984375af\Project.toml
  package version:               0.4.0-DEV
  saved states:                  11
  final integration time:        0.2
  maximum relative energy drift: 1.8976077773855786e-15
  minimum pair separation:       0.820333610356794
  trajectory figure type:        Makie.Figure
  status:                         PASS
  Activating new project at `C:\Users\ian_g\AppData\Local\Temp\ThreeBody3D-fresh-11d95f8f94f94f5c89717c43984375af`
   Resolving package versions...
    Updating `C:\Users\ian_g\AppData\Local\Temp\ThreeBody3D-fresh-11d95f8f94f94f5c89717c43984375af\Project.toml`
  [56809431] + ThreeBody3D v0.4.0-DEV `C:\Users\ian_g\OneDrive\Documents\JuliaProjects\ThreeBody3D`
    Updating `C:\Users\ian_g\AppData\Local\Temp\ThreeBody3D-fresh-11d95f8f94f94f5c89717c43984375af\Manifest.toml`
  [47edcb42] + ADTypes v1.22.2
  [14f7f29c] + AMD v0.5.3
  [621f4979] + AbstractFFTs v1.5.0
  [1520ce14] + AbstractTrees v0.4.5
  [7d9f7c33] + Accessors v0.1.45
  [79e6a3ab] + Adapt v4.7.0
  [35492f91] + AdaptivePredicates v1.2.0
  [66dad0bd] + AliasTables v1.1.3
  [27a7e980] + Animations v0.4.2
  [4fba245c] + ArrayInterface v7.27.0
  [67c07d97] + Automa v1.2.0
  [13072b0f] + AxisAlgorithms v1.1.0
  [39de3d68] + AxisArrays v0.4.8
  [18cc8868] + BaseDirs v1.4.0
  [62783981] + BitTwiddlingConvenienceFunctions v0.1.6
âŒƒ [70df07ce] + BracketingNonlinearSolve v1.12.1
  [fa961155] + CEnum v0.5.0
  [2a0fbf3d] + CPUSummary v0.2.7
  [96374032] + CRlibm v1.0.2
  [d360d2e6] + ChainRulesCore v1.26.1
  [fb6a15b2] + CloseOpenIntervals v0.1.13
  [6b39b394] + CodecZstd v0.8.7
  [a2cac450] + ColorBrewer v0.4.2
  [35d6a980] + ColorSchemes v3.31.0
  [3da002f7] + ColorTypes v0.12.1
  [c3611d14] + ColorVectorSpace v0.11.0
  [5ae59095] + Colors v0.13.1
  [38540f10] + CommonSolve v0.2.11
  [bbf7d656] + CommonSubexpressions v0.3.1
  [f70d9fcc] + CommonWorldInvalidations v1.1.1
  [34da2185] + Compat v4.18.1
  [a33af91c] + CompositionsBase v0.1.2
  [95dc2771] + ComputePipeline v0.1.8
  [2569d6c7] + ConcreteStructs v0.2.6
  [187b0558] + ConstructionBase v1.6.0
  [d38c429a] + Contour v0.6.3
  [b7a15901] + CoreMath v0.1.0
  [adafc99b] + CpuId v0.3.1
  [9a962f9c] + DataAPI v1.16.0
  [864edb3b] + DataStructures v0.19.6
  [e2d170a0] + DataValueInterfaces v1.0.0
  [927a84f5] + DelaunayTriangulation v1.6.6
âŒ… [2b5f629d] + DiffEqBase v6.218.0
  [163ba53b] + DiffResults v1.1.0
  [b552c78f] + DiffRules v1.16.0
  [a0c0ee7d] + DifferentiationInterface v0.7.20
  [31c24e10] + Distributions v0.25.129
  [ffbed154] + DocStringExtensions v0.9.5
  [4e289a0a] + EnumX v1.0.7
  [f151be2c] + EnzymeCore v0.8.21
  [429591f6] + ExactPredicates v2.2.9
âŒƒ [d4d017d3] + ExponentialUtilities v1.31.0
  [e2ba6199] + ExprTools v0.1.10
  [55351af7] + ExproniconLite v0.10.14
  [b86e33f2] + FFTA v0.3.1
  [7034ab61] + FastBroadcast v1.3.4
  [9aa1b823] + FastClosures v0.3.2
  [442a2c76] + FastGaussQuadrature v1.3.0
  [a4df4552] + FastPower v1.3.4
  [5789e2e9] + FileIO v1.20.0
  [8fc22ac5] + FilePaths v0.9.0
  [48062228] + FilePathsBase v0.9.24
  [1a297f60] + FillArrays v1.16.0
  [6a86dc24] + FiniteDiff v2.32.0
âŒ… [53c48c17] + FixedPointNumbers v0.8.6
  [1fa38f19] + Format v1.3.7
  [f6369f11] + ForwardDiff v1.4.1
  [b38be410] + FreeType v4.1.1
  [663a7486] + FreeTypeAbstraction v0.10.8
  [069b7b12] + FunctionWrappers v1.1.3
  [77dc65aa] + FunctionWrappersWrappers v1.10.1
  [f7f18e0c] + GLFW v3.4.6
  [e9467ef8] + GLMakie v0.13.13
  [46192b85] + GPUArraysCore v0.2.0
  [a0844989] + Gamma v1.1.0
  [c145ed77] + GenericSchur v0.5.6
  [5c1252a2] + GeometryBasics v0.5.11
  [3955a311] + GridLayoutBase v0.11.2
  [34004b35] + HypergeometricFunctions v0.3.29
  [615f187c] + IfElse v0.1.1
  [2803e5a7] + ImageAxes v0.6.12
  [c817782e] + ImageBase v0.1.7
  [a09fc81d] + ImageCore v0.10.5
  [82e4d734] + ImageIO v0.6.9
  [bc367c6b] + ImageMetadata v0.9.10
  [9b13fd28] + IndirectArrays v1.0.0
  [d25df0c9] + Inflate v0.1.5
  [18e54dd8] + IntegerMathUtils v0.1.3
  [a98d9a8b] + Interpolations v0.16.3
  [d1acc4aa] + IntervalArithmetic v1.0.10
  [8197267c] + IntervalSets v0.7.14
  [3587e190] + InverseFunctions v0.1.17
  [92d709cd] + IrrationalConstants v0.2.6
  [f1662d9f] + Isoband v0.1.1
  [c8e1da08] + IterTools v1.10.0
  [82899510] + IteratorInterfaceExtensions v1.0.0
  [692b3bcd] + JLLWrappers v1.8.0
  [682c06a0] + JSON v1.6.1
  [ae98c720] + Jieko v0.2.1
  [b835a17e] + JpegTurbo v0.1.6
  [5ab0869b] + KernelDensity v0.6.12
  [ba0b0d4f] + Krylov v0.10.8
  [b964fa9f] + LaTeXStrings v1.4.0
  [10f19ff3] + LayoutPointers v0.1.17
  [8cdb02fc] + LazyModules v0.3.1
  [87fe0de2] + LineSearch v0.1.12
  [d3d80556] + LineSearches v7.7.1
âŒ… [7ed4a6bd] + LinearSolve v3.87.0
  [2ab3a3ac] + LogExpFunctions v1.0.1
  [e6f89c97] + LoggingExtras v1.2.0
  [1914dd2f] + MacroTools v0.5.16
  [ee78f7c6] + Makie v0.24.13
  [d125e4d3] + ManualMemory v0.1.8
  [dbb5928d] + MappedArrays v0.4.3
  [0a4f8689] + MathTeXEngine v0.6.9
  [bb5d69b7] + MaybeInplace v0.1.6
  [7269a6da] + MeshIO v0.5.3
  [e1d29d7a] + Missings v1.2.0
  [66fc600b] + ModernGL v1.1.8
  [e94cdb99] + MosaicViews v0.3.4
  [2e0e35c7] + Moshi v0.3.12
  [46d2c3a1] + MuladdMacro v0.2.6
  [d41bc354] + NLSolversBase v8.0.0
  [77ba4419] + NaNMath v1.1.4
  [f09324ee] + Netpbm v1.1.1
âŒƒ [8913a72c] + NonlinearSolve v4.19.1
âŒ… [be0214bd] + NonlinearSolveBase v2.30.3
âŒƒ [5959db7a] + NonlinearSolveFirstOrder v2.1.1
âŒƒ [9a2c21bd] + NonlinearSolveQuasiNewton v1.13.1
âŒƒ [26075421] + NonlinearSolveSpectralMethods v1.7.1
  [510215fc] + Observables v0.5.5
  [6fe1bfb0] + OffsetArrays v1.17.0
  [52e1d378] + OpenEXR v0.3.3
  [bac558e1] + OrderedCollections v2.0.1
âŒƒ [1dea7af3] + OrdinaryDiffEq v6.111.0
âŒ… [89bda076] + OrdinaryDiffEqAdamsBashforthMoulton v1.11.0
âŒ… [6ad6398a] + OrdinaryDiffEqBDF v1.26.0
âŒ… [bbf590c4] + OrdinaryDiffEqCore v3.33.1
âŒ… [50262376] + OrdinaryDiffEqDefault v1.14.0
âŒ… [4302a76b] + OrdinaryDiffEqDifferentiation v2.9.0
âŒ… [9286f039] + OrdinaryDiffEqExplicitRK v1.12.0
âŒ… [e0540318] + OrdinaryDiffEqExponentialRK v1.15.0
âŒ… [becaefa8] + OrdinaryDiffEqExtrapolation v1.18.0
âŒ… [5960d6e9] + OrdinaryDiffEqFIRK v1.26.0
âŒ… [101fe9f7] + OrdinaryDiffEqFeagin v1.10.0
âŒ… [d3585ca7] + OrdinaryDiffEqFunctionMap v1.11.0
âŒ… [d28bc4f8] + OrdinaryDiffEqHighOrderRK v1.12.0
âŒ… [9f002381] + OrdinaryDiffEqIMEXMultistep v1.14.0
âŒ… [521117fe] + OrdinaryDiffEqLinear v1.12.0
âŒ… [1344f307] + OrdinaryDiffEqLowOrderRK v1.13.0
âŒ… [b0944070] + OrdinaryDiffEqLowStorageRK v1.15.0
âŒ… [127b3ac7] + OrdinaryDiffEqNonlinearSolve v1.28.0
âŒ… [c9986a66] + OrdinaryDiffEqNordsieck v1.11.0
âŒ… [5dd0a6cf] + OrdinaryDiffEqPDIRK v1.14.0
âŒ… [5b33eab2] + OrdinaryDiffEqPRK v1.10.0
âŒ… [04162be5] + OrdinaryDiffEqQPRK v1.10.0
âŒ… [af6ede74] + OrdinaryDiffEqRKN v1.12.0
âŒ… [43230ef6] + OrdinaryDiffEqRosenbrock v1.31.1
âŒ… [2d112036] + OrdinaryDiffEqSDIRK v1.14.0
âŒ… [669c94d9] + OrdinaryDiffEqSSPRK v1.14.0
âŒ… [e3e12d00] + OrdinaryDiffEqStabilizedIRK v1.14.0
âŒ… [358294b1] + OrdinaryDiffEqStabilizedRK v1.11.1
âŒ… [fa646aed] + OrdinaryDiffEqSymplecticRK v1.13.0
âŒ… [b1df2697] + OrdinaryDiffEqTsit5 v1.12.0
âŒ… [79d7bb75] + OrdinaryDiffEqVerner v1.14.0
  [90014a1f] + PDMats v0.11.40
  [f57f5aa1] + PNGFiles v0.4.5
  [19eb6ba3] + Packing v0.5.1
  [5432bcbf] + PaddedViews v0.5.12
  [69de0a69] + Parsers v2.8.6
  [eebad327] + PkgVersion v0.3.3
  [995b91a9] + PlotUtils v1.4.4
  [f517fe37] + Polyester v0.7.19
  [1d0040c9] + PolyesterWeave v0.2.2
  [647866c9] + PolygonOps v0.1.2
  [d236fae5] + PreallocationTools v1.3.0
  [aea7be01] + PrecompileTools v1.3.4
  [21216c6a] + Preferences v1.5.2
  [27ebfcd6] + Primes v0.5.7
  [92933f4c] + ProgressMeter v1.11.0
  [43287f4e] + PtrArrays v1.4.0
  [0c0d3e7f] + PureKLU v1.1.1
  [4b34888f] + QOI v1.0.2
  [1fd47b50] + QuadGK v2.11.3
  [b3c3ace0] + RangeArrays v0.3.2
  [c84ed2f1] + Ratios v0.4.5
  [3cdcf5f2] + RecipesBase v1.3.4
âŒ… [731186ca] + RecursiveArrayTools v3.54.0
  [189a3867] + Reexport v1.2.2
  [05181044] + RelocatableFolders v1.0.1
  [ae029012] + Requires v1.3.1
  [79098fc4] + Rmath v0.9.0
  [f2b01f46] + Roots v3.0.6
  [5eaf0fd0] + RoundingEmulator v0.2.1
  [7e49a35a] + RuntimeGeneratedFunctions v0.5.22
  [fdea26ae] + SIMD v3.7.2
  [94e857df] + SIMDTypes v0.1.0
âŒ… [0bca4576] + SciMLBase v2.155.1
  [19f34311] + SciMLJacobianOperators v0.1.16
âŒ… [a6db7da4] + SciMLLogging v1.10.1
  [c0aeaf25] + SciMLOperators v1.24.3
  [431bcebd] + SciMLPublic v1.2.3
  [53ae85a6] + SciMLStructures v1.10.3
  [6c6a2e73] + Scratch v1.3.0
  [efcf1570] + Setfield v1.1.2
  [65257c39] + ShaderAbstractions v0.5.0
  [73760f76] + SignedDistanceFields v0.4.1
âŒƒ [727e6d20] + SimpleNonlinearSolve v2.12.0
  [699a6c99] + SimpleTraits v0.9.6
  [45858cf5] + Sixel v0.1.5
  [a2af1166] + SortingAlgorithms v1.2.3
  [a57abbd0] + SparseColumnPivotedQR v2.1.4
  [0a514795] + SparseMatrixColorings v0.4.27
  [276daf66] + SpecialFunctions v2.8.0
  [860ef19b] + StableRNGs v1.0.4
  [cae243ae] + StackViews v0.1.2
  [aedffcd0] + Static v1.4.4
  [0d7ed370] + StaticArrayInterface v1.10.0
  [90137ffa] + StaticArrays v1.9.18
  [1e83bf80] + StaticArraysCore v1.4.4
  [10745b16] + Statistics v1.11.1
  [82ae8749] + StatsAPI v1.8.0
  [2913bbd2] + StatsBase v0.34.12
  [4c63d2b9] + StatsFuns v2.2.0
  [7792a7ef] + StrideArraysCore v0.5.9
  [09ab397b] + StructArrays v0.7.3
  [ec057cc2] + StructUtils v2.8.2
  [2efcf032] + SymbolicIndexingInterface v0.3.51
  [3783bdb8] + TableTraits v1.0.1
  [bd369af6] + Tables v1.13.0
  [62fd8b95] + TensorCore v0.1.1
  [8290d209] + ThreadingUtilities v0.5.6
  [56809431] + ThreeBody3D v0.4.0-DEV `C:\Users\ian_g\OneDrive\Documents\JuliaProjects\ThreeBody3D`
  [731e570b] + TiffImages v0.11.9
  [a759f4b9] + TimerOutputs v0.5.29
  [3bb67fe8] + TranscodingStreams v0.11.3
  [981d1d27] + TriplotBase v0.1.0
  [781d530d] + TruncatedStacktraces v1.4.0
  [1cfade01] + UnicodeFun v0.4.1
  [1986cc42] + Unitful v1.28.0
  [e3aaa7dc] + WebP v0.1.3
  [efce3f68] + WoodburyMatrices v1.1.0
  [6e34b625] + Bzip2_jll v1.0.9+0
  [4e9b3aee] + CRlibm_jll v1.0.1+0
  [83423d85] + Cairo_jll v1.18.7+0
  [a38c48d9] + CoreMath_jll v0.1.0+0
  [ee1fde0b] + Dbus_jll v1.16.2+0
  [5ae413db] + EarCut_jll v2.2.4+0
  [2702e6a9] + EpollShim_jll v0.0.20230411+1
  [2e619515] + Expat_jll v2.8.2+0
  [b22a6f82] + FFMPEG_jll v8.1.2+0
  [a3f928ae] + Fontconfig_jll v2.17.1+0
  [d7e528f0] + FreeType2_jll v2.14.3+1
  [559328eb] + FriBidi_jll v1.0.17+0
  [0656b61e] + GLFW_jll v3.4.1+1
âŒ… [b0724c58] + GettextRuntime_jll v0.22.4+0
  [59f7168a] + Giflib_jll v5.2.3+0
  [7746bdde] + Glib_jll v2.86.3+0
  [3b182d85] + Graphite2_jll v1.3.16+0
âŒ… [2e76f6c2] + HarfBuzz_jll v8.5.1+0
  [905a6f67] + Imath_jll v3.2.2+0
  [1d5cc7b8] + IntelOpenMP_jll v2025.2.0+0
  [aacddb02] + JpegTurbo_jll v3.2.0+0
  [c1c5ebd0] + LAME_jll v3.100.3+0
  [88015f11] + LERC_jll v4.1.0+0
  [1d63c593] + LLVMOpenMP_jll v22.1.7+0
âŒ… [e9f186c6] + Libffi_jll v3.4.7+0
  [7e76a0d4] + Libglvnd_jll v1.7.1+1
  [94ce4f54] + Libiconv_jll v1.18.0+0
  [4b2f31a3] + Libmount_jll v2.42.0+0
  [89763e89] + Libtiff_jll v4.7.3+0
  [38a345b3] + Libuuid_jll v2.42.0+0
  [856f044c] + MKL_jll v2025.2.0+0
  [e7412a2a] + Ogg_jll v1.3.6+0
  [6cdc7f73] + OpenBLASConsistentFPCSR_jll v0.3.33+1
  [18a262bb] + OpenEXR_jll v3.4.13+0
  [efe28fd5] + OpenSpecFun_jll v0.5.6+0
  [91d4177d] + Opus_jll v1.6.1+0
  [36c8627f] + Pango_jll v1.57.1+0
  [30392449] + Pixman_jll v0.46.4+0
  [f50d1b31] + Rmath_jll v0.5.1+0
  [a2964d1f] + Wayland_jll v1.24.0+0
  [ffd25f8a] + XZ_jll v5.8.3+0
  [4f6342f7] + Xorg_libX11_jll v1.8.13+0
  [0c0b7dd1] + Xorg_libXau_jll v1.0.13+0
  [935fb764] + Xorg_libXcursor_jll v1.2.4+0
  [a3789734] + Xorg_libXdmcp_jll v1.1.6+0
  [1082639a] + Xorg_libXext_jll v1.3.8+0
  [d091e8ba] + Xorg_libXfixes_jll v6.0.2+0
  [a51aa0fd] + Xorg_libXi_jll v1.8.3+0
  [d1454406] + Xorg_libXinerama_jll v1.1.7+0
  [ec84b674] + Xorg_libXrandr_jll v1.5.6+0
  [ea2f1a96] + Xorg_libXrender_jll v0.9.12+0
  [a65dc6b1] + Xorg_libpciaccess_jll v0.19.0+0
  [c7cfdc94] + Xorg_libxcb_jll v1.17.1+0
  [cc61e674] + Xorg_libxkbfile_jll v1.2.0+0
  [35661453] + Xorg_xkbcomp_jll v1.4.7+0
  [33bec58e] + Xorg_xkeyboard_config_jll v2.47.0+2
  [c5fb5394] + Xorg_xtrans_jll v1.6.0+0
  [3161d3a3] + Zstd_jll v1.5.7+1
  [9a68df92] + isoband_jll v0.2.3+0
  [a4ae2306] + libaom_jll v3.13.3+0
  [0ac62f75] + libass_jll v0.17.4+0
  [1183f4f0] + libdecor_jll v0.2.2+0
  [8e53e030] + libdrm_jll v2.4.125+1
  [f638f0a6] + libfdk_aac_jll v2.0.4+0
  [b53b4c65] + libpng_jll v1.6.58+0
  [075b6546] + libsixel_jll v1.10.5+0
  [9a156e7d] + libva_jll v2.23.0+0
  [f27f6e37] + libvorbis_jll v1.3.8+0
  [c5f90fcd] + libwebp_jll v1.6.0+0
  [1317d2d5] + oneTBB_jll v2022.3.0+0
âŒ… [1270edf5] + x264_jll v10164.0.1+0
  [dfaa095f] + x265_jll v4.1.0+0
  [d8fb68d0] + xkbcommon_jll v1.13.0+0
  [0dad84c5] + ArgTools v1.1.2
  [56f22d72] + Artifacts v1.11.0
  [2a0f44e3] + Base64 v1.11.0
  [8bf52ea8] + CRC32c v1.11.0
  [ade2ca70] + Dates v1.11.0
  [8ba89e20] + Distributed v1.11.0
  [f43a241f] + Downloads v1.7.0
  [7b1f6079] + FileWatching v1.11.0
  [9fa8497b] + Future v1.11.0
  [b77e0a4c] + InteractiveUtils v1.11.0
  [ac6e5ff7] + JuliaSyntaxHighlighting v1.12.0
  [4af54fe1] + LazyArtifacts v1.11.0
  [b27032c2] + LibCURL v0.6.4
  [76f85450] + LibGit2 v1.11.0
  [8f399da3] + Libdl v1.11.0
  [37e2e46d] + LinearAlgebra v1.12.0
  [56ddb016] + Logging v1.11.0
  [d6f4376e] + Markdown v1.11.0
  [a63ad114] + Mmap v1.11.0
  [ca575930] + NetworkOptions v1.3.0
  [44cfe95a] + Pkg v1.12.1
  [de0858da] + Printf v1.11.0
  [3fa0cd96] + REPL v1.11.0
  [9a3f8284] + Random v1.11.0
  [ea8e919c] + SHA v0.7.0
  [9e88b42a] + Serialization v1.11.0
  [1a1011a3] + SharedArrays v1.11.0
  [6462fe0b] + Sockets v1.11.0
  [2f01184e] + SparseArrays v1.12.0
  [f489334b] + StyledStrings v1.11.0
  [4607b0f0] + SuiteSparse
  [fa267f1f] + TOML v1.0.3
  [a4e569a6] + Tar v1.10.0
  [cf7118a7] + UUIDs v1.11.0
  [4ec0a83e] + Unicode v1.11.0
  [e66e0078] + CompilerSupportLibraries_jll v1.3.0+1
  [deac9b47] + LibCURL_jll v8.15.0+0
  [e37daf67] + LibGit2_jll v1.9.0+0
  [29816b5a] + LibSSH2_jll v1.11.3+1
  [14a3606d] + MozillaCACerts_jll v2025.11.4
  [4536629a] + OpenBLAS_jll v0.3.29+0
  [05823500] + OpenLibm_jll v0.8.7+0
  [458c3c95] + OpenSSL_jll v3.5.4+0
  [efcefdf7] + PCRE2_jll v10.44.0+1
  [bea87d4a] + SuiteSparse_jll v7.8.3+2
  [83775a58] + Zlib_jll v1.3.1+2
  [8e850b90] + libblastrampoline_jll v5.15.0+0
  [8e850ede] + nghttp2_jll v1.64.0+1
  [3f19e933] + p7zip_jll v17.7.0+0
        Info Packages marked with âŒƒ and âŒ… have new versions available. Those with âŒƒ may be upgradable, but those with âŒ… are restricted by compatibility constraints from upgrading. To see why use `status --outdated -m`
```
