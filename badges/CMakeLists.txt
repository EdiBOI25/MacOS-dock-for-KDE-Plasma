cmake_minimum_required(VERSION 3.16)

project(icontasks2byedi-badges)

find_package(ECM 6.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 6.6 REQUIRED COMPONENTS Core)

if(BUILD_TESTING)
    find_package(Qt6 6.6 REQUIRED COMPONENTS Test)
    include(ECMAddTests)
    ecm_add_test(tests/badgestatetest.cpp badgestate.cpp
        TEST_NAME badgestatetest
        LINK_LIBRARIES Qt6::Core Qt6::Test)
    target_include_directories(badgestatetest PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
endif()
