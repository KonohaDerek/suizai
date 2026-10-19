cmake_minimum_required(VERSION 3.22.1)
project(suizai_android C)

add_library(suizai_core STATIC IMPORTED)
set_target_properties(suizai_core PROPERTIES IMPORTED_LOCATION
    "${CMAKE_CURRENT_LIST_DIR}/../../../build/rust/${ANDROID_ABI}/libsuizai_core.a")
add_library(suizai_bridge SHARED suizai_bridge.c)
target_include_directories(suizai_bridge PRIVATE "${CMAKE_CURRENT_LIST_DIR}/../../../../core/include")
target_link_libraries(suizai_bridge suizai_core log dl m)
target_link_options(suizai_bridge PRIVATE "-Wl,-z,max-page-size=16384")
