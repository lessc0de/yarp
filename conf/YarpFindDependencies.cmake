# Copyright (C) 2009  RobotCub Consortium
# Copyright (C) 2012  iCub Facility, Istituto Italiano di Tecnologia
# Authors: Lorenzo Natale, Daniele E. Domenichelli <daniele.domenichelli@iit.it>
# CopyPolicy: Released under the terms of the LGPLv2.1 or later, see LGPL.TXT

# This module checks if all the dependencies are installed and if the
# dependencies to build some parts of Yarp are satisfied.
# For every dependency, it creates the following variables:
#
# YARP_USE_${PACKAGE}: Can be disabled by the user if he doesn't want to use that
#                      dependency.
# YARP_HAS_${PACKAGE}: Internal flag. It should be used to check if a part of
#                      Yarp should be built. It is on if YARP_USE_${PACKAGE} is
#                      on and either the package was found or will be built.
# YARP_USE_SYSTEM_${PACKAGE}: This flag is shown only for packages in the
#                             extern folder that were also found on the system
#                             (TRUE by default). If this flag is enabled, the
#                             system installed library will be used instead of
#                             the version shipped with Yarp.


include(YarpRenamedOption)

# USEFUL MACROS:

# Check if a package is installed and set some cmake variables
macro(checkandset_dependency package)

    string(TOUPPER ${package} PKG)

    # YARP_HAS_SYSTEM_${PKG}
    if(${package}_FOUND OR ${PKG}_FOUND)
        set(YARP_HAS_SYSTEM_${PKG} TRUE)
    else()
        set(YARP_HAS_SYSTEM_${PKG} FALSE)
    endif()

    # YARP_USE_${PKG}
    cmake_dependent_option(YARP_USE_${PKG} "Use package ${package}" TRUE
                           YARP_HAS_SYSTEM_${PKG} FALSE)
    mark_as_advanced(YARP_USE_${PKG})

    # YARP_USE_SYSTEM_${PKG}
    set(YARP_USE_SYSTEM_${PKG} ${YARP_USE_${PKG}} CACHE INTERNAL "Use system-installed ${package}, rather than a private copy (recommended)" FORCE)

    # YARP_HAS_${PKG}
    if(${YARP_HAS_SYSTEM_${PKG}})
        set(YARP_HAS_${PKG} ${YARP_USE_${PKG}})
    else()
        set(YARP_HAS_${PKG} FALSE)
    endif()

endmacro (checkandset_dependency)


# Check if a package is installed or if is going to be built and set some cmake variables
macro(checkbuildandset_dependency package)

    string(TOUPPER ${package} PKG)

    # YARP_HAS_SYSTEM_${PKG}
    if (${package}_FOUND OR ${PKG}_FOUND)
        set(YARP_HAS_SYSTEM_${PKG} TRUE)
    else()
        set(YARP_HAS_SYSTEM_${PKG} FALSE)
    endif()

    # YARP_USE_${PKG}
    option(YARP_USE_${PKG} "Use package ${package}" TRUE)
    mark_as_advanced(YARP_USE_${PKG})

    # YARP_USE_SYSTEM_${PKG}
    cmake_dependent_option(YARP_USE_SYSTEM_${PKG} "Use system-installed ${package}, rather than a private copy (recommended)" TRUE
                           "YARP_HAS_SYSTEM_${PKG};YARP_USE_${PKG}" FALSE)
    mark_as_advanced(YARP_USE_SYSTEM_${PKG})

    # YARP_HAS_${PKG}
    set(YARP_HAS_${PKG} ${YARP_USE_${PKG}})

endmacro(checkbuildandset_dependency)


# Check if a required package is installed.
macro(check_required_dependency package)

    string(TOUPPER ${package} PKG)

    if(NOT YARP_HAS_${PKG})
        message(FATAL_ERROR "Required package ${package} not found. Please install it to build yarp.")
#    else()
#        message(STATUS "${PKG} -> OK")
    endif()

endmacro(check_required_dependency)


# Check if a dependency required to enable an option is installed.
macro(check_optional_dependency optionname package)

    string(TOUPPER ${package} PKG)

    if(${optionname})
        if(NOT YARP_HAS_${PKG})
            message(FATAL_ERROR "Optional package ${package} not found. Please install it or disable the option \"${optionname}\" to build yarp.")
#        else()
#            message(STATUS "${PKG} ${optionname} -> OK")
        endif()
#    else()
#        message(STATUS "${PKG} ${optionname} -> NOT REQUIRED")
    endif()

endmacro(check_optional_dependency)


# Check if at least one of the dependency required to enable an option is installed.
function(check_alternative_dependency optionname)
    if(${optionname})
        foreach(package "${ARGN}")
            string(TOUPPER ${package} PKG)
            if(YARP_HAS_${PKG})
                return()
            endif()
        endforeach()
        message(FATAL_ERROR "None of the alternative packages \"${ARGN}\" was found. Please install at least one of them or disable the option \"${optionname}\" to build yarp.")
    endif()
endfunction()


# Check if a dependency required to disable an option is installed.
macro(check_skip_dependency optionname package)
    string(TOUPPER ${package} PKG)

    if(NOT ${optionname})
        if(NOT YARP_HAS_${PKG})
            message(FATAL_ERROR "Optional package ${package} not found. Please install it or enable the option \"${optionname}\" to build yarp.")
        endif()
    endif()
endmacro()


# Print status for a dependency
macro(print_dependency package)

    string(TOUPPER ${package} PKG)

#    message("YARP_HAS_SYSTEM_${PKG} = ${YARP_HAS_SYSTEM_${PKG}}")
#    message("YARP_USE_${PKG} = ${YARP_USE_${PKG}}")
#    message("YARP_USE_SYSTEM_${PKG} = ${YARP_USE_SYSTEM_${PKG}}")
#    message("YARP_HAS_${PKG} = ${YARP_HAS_${PKG}}")
    if(DEFINED ${package}_REQUIRED_VERSION)
        set(_version " (${${package}_REQUIRED_VERSION})")
    endif()
    if(NOT DEFINED YARP_HAS_${PKG})
        message(STATUS " +++ ${package}${_version}: disabled")
    elseif(NOT YARP_HAS_${PKG})
        message(STATUS " +++ ${package}${_version}: not found")
    elseif(YARP_HAS_SYSTEM_${PKG} AND YARP_USE_SYSTEM_${PKG})
        message(STATUS " +++ ${package}${_version}: found")
    elseif(YARP_HAS_SYSTEM_${PKG})
        message(STATUS " +++ ${package}${_version}: compiling (system package disabled)")
    else()
        message(STATUS " +++ ${package}${_version}: compiling (not found)")
    endif()
    unset(_version)

endmacro(print_dependency)


# OPTIONS:

option(SKIP_ACE "Compile YARP without ACE (Linux only, TCP only, limited functionality)" OFF)
mark_as_advanced(SKIP_ACE)


option(CREATE_LIB_MATH "Create math library libYARP_math?" OFF)
if(CREATE_LIB_MATH)
    # FIXME YARP_USE_ATLAS is probably not a good choice since it can make
    #       confusion with YARP_USE_Atlas (generated by checkandset_dependency
    #       macro)
    option(YARP_USE_ATLAS "Enable to link to Atlas for BLAS" OFF)
else()
    unset(YARP_USE_ATLAS)
endif()

option(CREATE_YARPMANAGER_CONSOLE "Do you want to compile YARP Module Manager (console)?" ON)
yarp_renamed_option(CREATE_YMANAGER CREATE_YARPMANAGER_CONSOLE)

option(CREATE_YARPDATADUMPER "Do you want to compile yarpdatadumper?" ON)

option(CREATE_GUIS "Do you want to compile GUIs" OFF)

if(CREATE_GUIS)
    option(CREATE_YARPVIEW "Do you want to compile yarpview?" ON)
    option(CREATE_YARPMANAGER "Do you want to compile yarpmanager?" ON)
    option(CREATE_YARPLOGGER "Do you want to create yarplogger?" ON)
    option(CREATE_YARPSCOPE "Do you want to create yarpscope?" ON)
    option(CREATE_YARPBUILDER "Do you want to compile YARP Application Builder?" OFF)
    option(CREATE_YARPDATAPLAYER "Do you want to compile yarpdataplayer?" ON)
    option(CREATE_YARPMOTORGUI "Do you want to compile yarpmotorgui?" ON)
    option(CREATE_YARPBATTERYGUI "Do you want to compile yarpbatterygui?" ON)
    yarp_renamed_option(CREATE_GYARPMANAGER CREATE_YARPMANAGER)
    yarp_renamed_option(CREATE_GYARPBUILDER CREATE_YARPBUILDER)
else()
    unset(CREATE_YARPVIEW CACHE)
    unset(CREATE_YARPMANAGER CACHE)
    unset(CREATE_YARPLOGGER CACHE)
    unset(CREATE_YARPSCOPE CACHE)
    unset(CREATE_YARPBUILDER CACHE)
    unset(CREATE_YARPDATAPLAYER CACHE)
    unset(CREATE_YARPMOTORGUI CACHE)
endif()

if(CREATE_YARPMANAGER_CONSOLE OR CREATE_YARPMANAGER OR CREATE_YARPBUILDER)
    set(CREATE_LIB_MANAGER ON CACHE INTERNAL "Create manager library libYARP_manager?")
else()
    unset(CREATE_LIB_MANAGER CACHE)
endif()


message(STATUS "Detecting required libraries")
message(STATUS "CMake modules directory: ${CMAKE_MODULE_PATH}")


# FIND PACKAGES:

if(SKIP_ACE)
    if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
        set(ACE_LIBRARIES pthread rt dl)
    endif()
else()
    find_package(ACE)
    checkandset_dependency(ACE)
    # FIXME Replace SKIP_ACE with YARP_USE_ACE
    set_property(CACHE YARP_USE_ACE PROPERTY TYPE INTERNAL)
    set_property(CACHE YARP_USE_ACE PROPERTY VALUE TRUE)
    if(SKIP_ACE)
        set_property(CACHE YARP_USE_ACE PROPERTY VALUE FALSE)
    endif()

    # __ACE_INLINE__ is needed in some configurations
    if(NOT ACE_COMPILES_WITHOUT_INLINE_RELEASE)
        foreach(_config ${YARP_OPTIMIZED_CONFIGURATIONS})
            string(TOUPPER ${_config} _CONFIG)
            set(CMAKE_C_FLAGS_${_CONFIG} "${CMAKE_C_FLAGS_${_CONFIG}} -D__ACE_INLINE__")
            set(CMAKE_CXX_FLAGS_${_CONFIG} "${CMAKE_CXX_FLAGS_${_CONFIG}} -D__ACE_INLINE__")
        endforeach()
    endif()

    if(NOT ACE_COMPILES_WITHOUT_INLINE_DEBUG)
        foreach(_config ${YARP_DEBUG_CONFIGURATIONS})
            string(TOUPPER ${_config} _CONFIG)
            set(CMAKE_C_FLAGS_${_CONFIG} "${CMAKE_C_FLAGS_${_CONFIG}} -D__ACE_INLINE__")
            set(CMAKE_CXX_FLAGS_${_CONFIG} "${CMAKE_CXX_FLAGS_${_CONFIG}} -D__ACE_INLINE__")
        endforeach()
    endif()
endif()

find_package(SQLite)
checkbuildandset_dependency(SQLite)

find_package(Readline)
checkandset_dependency(Readline)

if(CREATE_LIB_MATH)
    find_package(GSL)
    checkandset_dependency(GSL)
    if(YARP_USE_ATLAS)
        find_package(Atlas)
        checkandset_dependency(Atlas)
    endif()
endif()

if(CREATE_YARPSCOPE OR CREATE_LIB_MANAGER)
    set(TinyXML_REQUIRED_VERSION 2.6)
    find_package(TinyXML ${TinyXML_REQUIRED_VERSION})
    checkbuildandset_dependency(TinyXML)
endif()

if(CREATE_GUIS)
    if(CREATE_YARPSCOPE)
        set(GTK2_REQUIRED_VERSION 2.20)
        set(GTK2_REQUIRED_COMPONENTS gtk gtkmm)
    elseif(CREATE_YARPMANAGER OR CREATE_YARPBUILDER)
        set(GTK2_REQUIRED_VERSION 2.8)
        set(GTK2_REQUIRED_COMPONENTS gtk gtkmm)
    elseif(CREATE_YARPVIEW)
        set(GTK2_REQUIRED_VERSION 2.8)
        set(GTK2_REQUIRED_COMPONENTS gtk)
    endif()
    find_package(GTK2 ${GTK2_REQUIRED_VERSION} COMPONENTS ${GTK2_REQUIRED_COMPONENTS})

    checkandset_dependency(GTK2)

    ### FIXME: remove this check when stop supporting debian etch
    ### FIXME: FindGtkMM reports the wrong version on windows, since
    ###        this is a problem strictly related to debian etch, for
    ###        now we do this check only on UNIX.
    if (UNIX AND CREATE_YARPSCOPE)
        if (GtkMM_VERSION_MAJOR GREATER 2 OR GtkMM_VERSION_MAJOR EQUAL 2)
            if (GtkMM_VERSION_MINOR LESS 20)
                message(STATUS "Detected version of GtkMM that does not support yarpscope, turning off CREATE_YARPSCOPE")
                set_property(CACHE CREATE_YARPSCOPE PROPERTY VALUE FALSE)
            endif()
        endif()
    endif()

    find_package(Qt5 COMPONENTS Core Widgets Gui Quick Qml Multimedia Xml PrintSupport QUIET)
    checkandset_dependency(Qt5)
endif()

if(CREATE_YARPSCOPE)
    find_package(GtkDatabox)
    checkbuildandset_dependency(GtkDatabox)
    set(GtkDataboxMM_REQUIRED_VERSION 0.9.3)
    find_package(GtkDataboxMM ${GtkDataboxMM_REQUIRED_VERSION})
    checkbuildandset_dependency(GtkDataboxMM)
endif()

if(CREATE_YARPBUILDER)
    find_package(GooCanvas)
    checkbuildandset_dependency(GooCanvas)
    find_package(GooCanvasMM)
    checkbuildandset_dependency(GooCanvasMM)
endif()

if(YARP_COMPILE_BINDINGS)
    set(SWIG_REQUIRED_VERSION 1.3.29)
    find_package(SWIG ${SWIG_REQUIRED_VERSION})
    checkandset_dependency(SWIG)
endif()

if(CREATE_YARPDATADUMPER OR CREATE_YARPDATAPLAYER OR ENABLE_yarpmod_opencv_grabber)
    find_package(OpenCV)
    checkandset_dependency(OpenCV)
endif()

if(ENABLE_yarpcar_portmonitor_carrier)
    find_package(Lua)
    checkandset_dependency(Lua)
endif()


# PRINT DEPENDENCIES STATUS:

message(STATUS "I have found the following libraries:")
print_dependency(ACE)
print_dependency(SQLite)
print_dependency(GSL)
print_dependency(Atlas)
print_dependency(TinyXML)
print_dependency(GTK2)
print_dependency(Qt5)
print_dependency(GtkDatabox)
print_dependency(GtkDataboxMM)
print_dependency(GooCanvas)
print_dependency(GooCanvasMM)
print_dependency(Readline)
print_dependency(SWIG)
print_dependency(OpenCV)
print_dependency(Lua)


# CHECK DEPENDENCIES:

check_skip_dependency(SKIP_ACE ACE)
check_required_dependency(SQLite)
check_optional_dependency(CREATE_LIB_MATH GSL)
check_optional_dependency(YARP_USE_ATLAS Atlas)
check_optional_dependency(CREATE_LIB_MANAGER TinyXML)
check_optional_dependency(CREATE_YARPSCOPE TinyXML)
check_alternative_dependency(CREATE_GUIS GTK2 Qt5)
check_alternative_dependency(CREATE_YARPSCOPE GtkDatabox Qt5)
check_alternative_dependency(CREATE_YARPSCOPE GtkDataboxMM Qt5)
check_optional_dependency(CREATE_YARPBUILDER GooCanvas)
check_optional_dependency(CREATE_YARPBUILDER GooCanvasMM)
check_optional_dependency(YARP_COMPILE_BINDINGS SWIG)
check_optional_dependency(ENABLE_yarpmod_opencv_grabber OpenCV)
check_optional_dependency(ENABLE_yarpcar_portmonitor_carrier Lua)



#########################################################################
# Print information for user (CDash)
if (CREATE_LIB_MATH)
    message(STATUS "YARP_math selected for compilation")
endif()
if (CREATE_GUIS)
    message(STATUS "GUIs selected for compilation")
endif()
