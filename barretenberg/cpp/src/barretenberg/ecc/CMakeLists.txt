# Auto-discover source files
file(GLOB_RECURSE SOURCE_FILES *.cpp)
file(GLOB_RECURSE HEADER_FILES *.hpp *.tcc)
file(GLOB_RECURSE TEST_SOURCE_FILES *.test.cpp)
file(GLOB_RECURSE BENCH_SOURCE_FILES *.bench.cpp)
file(GLOB_RECURSE FUZZERS_SOURCE_FILES *.fuzzer.cpp)
list(FILTER SOURCE_FILES EXCLUDE REGEX ".*\\.(fuzzer|test|bench)\\.cpp$")

# Conditionally exclude assembly-dependent benchmarks when ASM is disabled
if(DISABLE_ASM)
    list(FILTER BENCH_SOURCE_FILES EXCLUDE REGEX ".*/fr_straight\\.bench\\.cpp$")
endif()

barretenberg_module_with_sources(
    ecc
    SOURCE_FILES ${SOURCE_FILES}
    HEADER_FILES ${HEADER_FILES}
    TEST_SOURCE_FILES ${TEST_SOURCE_FILES}
    BENCH_SOURCE_FILES ${BENCH_SOURCE_FILES}
    FUZZERS_SOURCE_FILES ${FUZZERS_SOURCE_FILES}
    DEPENDENCIES numeric crypto_keccak crypto_sha256
)

if(DISABLE_ADX)
    message(STATUS "Disabling ADX assembly variant.")
    target_compile_definitions(ecc PRIVATE -DDISABLE_ADX)
endif()

target_precompile_headers(
    ecc
    PUBLIC
    "$<$<COMPILE_LANGUAGE:CXX>:<random$<ANGLE-R>>"
    $<$<COMPILE_LANGUAGE:CXX>:"barretenberg/numeric/uint256/uint256.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"barretenberg/numeric/uint256/uint256_impl.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/asm_macros.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/field_declarations.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/field_impl.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/field_impl_generic.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/field_impl_x64.hpp">
    $<$<COMPILE_LANGUAGE:CXX>:"${CMAKE_CURRENT_SOURCE_DIR}/fields/field.hpp">
)
