include(ExternalProject)
include(ProcessorCount)

set(DESTDIR "${CMAKE_CURRENT_BINARY_DIR}/destdir" CACHE PATH "Destination directory")
set(DEP_DOWNLOAD_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE PATH "Path for downloaded source packages.")
option(DEP_BUILD_VERBOSE "Use verbose output for each dependency build" OFF)

get_property(_is_multi GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)

if (NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release)
    message(STATUS "Forcing CMAKE_BUILD_TYPE to Release as it was not specified.")
endif ()

# The value of CMAKE_BUILD_TYPE will be used for building each dependency even if the 
# generator is multi-config. Use this var to specify build type regardless of the generator. 
function(add_cmake_project projectname)
    cmake_parse_arguments(P_ARGS "" "INSTALL_DIR;BUILD_COMMAND;INSTALL_COMMAND" "CMAKE_ARGS" ${ARGN})

    set(_pcount ${DEP_${projectname}_MAX_THREADS})

    if (NOT _pcount)
        set(_pcount ${DEP_MAX_THREADS})
    endif ()

    if (NOT _pcount)
        ProcessorCount(_pcount)
    endif ()

    if (_pcount EQUAL 0)
        set(_pcount 1)
    endif ()

    set(_build_j "-j${_pcount}")
    if (CMAKE_GENERATOR MATCHES "Visual Studio")
        set(_build_j "-m:${_pcount}")
    endif ()

    string(TOUPPER "${CMAKE_BUILD_TYPE}" _build_type_upper)
    set(_configs_line -DCMAKE_BUILD_TYPE:STRING=${CMAKE_BUILD_TYPE})
    if (_is_multi)
        set(_configs_line "")
    endif ()

    set(_verbose_switch "")
    if (CMAKE_GENERATOR MATCHES "Ninja")
        set(_verbose_switch "--verbose")
    endif ()

    ExternalProject_Add(
        dep_${projectname}
        EXCLUDE_FROM_ALL    ON  # Not built by default, dep_${projectname} needs to be added to ALL target
        INSTALL_DIR         ${DESTDIR}/usr/local
        DOWNLOAD_DIR        ${DEP_DOWNLOAD_DIR}/${projectname}
        CMAKE_ARGS
            -DCMAKE_INSTALL_PREFIX:STRING=${DESTDIR}/usr/local
            -DCMAKE_MODULE_PATH:STRING=${CMAKE_MODULE_PATH}
            -DCMAKE_PREFIX_PATH:STRING=${DESTDIR}/usr/local
            -DCMAKE_DEBUG_POSTFIX:STRING=${CMAKE_DEBUG_POSTFIX}
            -DCMAKE_C_COMPILER:STRING=${CMAKE_C_COMPILER}
            -DCMAKE_CXX_COMPILER:STRING=${CMAKE_CXX_COMPILER}
            -DCMAKE_CXX_FLAGS_${_build_type_upper}:STRING=${CMAKE_CXX_FLAGS_${_build_type_upper}}
            -DCMAKE_C_FLAGS_${_build_type_upper}:STRING=${CMAKE_C_FLAGS_${_build_type_upper}}
            -DCMAKE_TOOLCHAIN_FILE:STRING=${CMAKE_TOOLCHAIN_FILE}
            -DBUILD_SHARED_LIBS:BOOL=OFF
            "${_configs_line}"
            ${DEP_CMAKE_OPTS}
            ${P_ARGS_CMAKE_ARGS}
       ${P_ARGS_UNPARSED_ARGUMENTS}
       BUILD_COMMAND ${CMAKE_COMMAND} --build . --config ${CMAKE_BUILD_TYPE} -- ${_build_j} ${_verbose_switch}
       INSTALL_COMMAND ${CMAKE_COMMAND} --build . --target install --config ${CMAKE_BUILD_TYPE}
    )

endfunction(add_cmake_project)
